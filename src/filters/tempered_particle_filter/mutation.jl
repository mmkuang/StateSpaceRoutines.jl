"""
```
mutation{S<:AbstractFloat}(system::System{S}, y_t::Array{S,1}, s_init::Array{S,1},
        ϵ_init::Array{S,1}, c::S, N_MH::Int, nonmissing::Array{Bool,1})
```
Runs random-walk Metropolis Hastings for single particle. The caller should loop through
all particles, calling this method on each.

### Inputs

- `system`: state-space system matrices
- `y_t`: vector of observables at time t
- `s_init`: vector of starting state before mutation (ŝ in paper)
- `ϵ_init`: vector of starting state error before mutation
- `c`: scaling factor used to achieve a desired acceptance rate, adjusted via:

    cₙ = cₙ₋₁f(1-R̂ₙ₋₁(cₙ₋₁))

    Where c₁ = c_star and R̂ₙ₋₁(cₙ₋₁) is the emprical rejection rate based on mutation
    phase in iteration n-1. Average is computed across previous N_MH RWMH steps.

- `N_MH`: number of Metropolis Hastings steps
- `nonmissing`: vector of booleans used to remove NaN values from matrices in system object

### Outputs

- `s_out`: mutated state vector
- `ϵ_out`: output ϵ shock corresponding to state vector
- `accept_rate`: acceptance rate across N_MH steps

"""
function mutation{S<:AbstractFloat}(Φ::Function, Ψ::Function, F_ϵ::Distribution,
                                    F_u::Distribution, φ_new::S, y_t::Vector{S}, s_non::Vector{S},
                                    s_init::Vector{S}, ϵ_init::Vector{S}, c::S, N_MH::Int)
    #------------------------------------------------------------------------
    # Setup
    #------------------------------------------------------------------------

    # Initialize s_out and ε_out
    s_out = s_init
    ϵ_out = ϵ_init

    HH = F_u.Σ.mat

    # Store length of y_t, ε
    n_obs    = length(y_t)
    n_states = length(ϵ_init)

    # Initialize acceptance counter to zero
    accept = 0.

    #------------------------------------------------------------------------
    # Metropolis-Hastings Steps
    #------------------------------------------------------------------------
    for i = 1:N_MH

        # Generate new draw of ε from a N(ε_init, c²I) distribution, c tuning parameter, I identity
        F_ϵ_new = MvNormal(ϵ_init, c^2*eye(length(ϵ_init)))
        ϵ_new   = rand(F_ϵ_new)

        # Use the state equation to calculate the corresponding state from that ε
        s_new = Φ(s_init, ϵ_new)

        # Calculate difference between data and expected y from measurement equation
        error_new  = y_t - Ψ(s_new, zeros(length(y_t)))
        error_init = y_t - Ψ(s_non, zeros(length(y_t)))

        # Calculate posteriors
        post_new = log(pdf(MvNormal(zeros(n_obs), HH/φ_new), error_new)[1] *
                       pdf(MvNormal(zeros(n_states), eye(n_states, n_states)), ϵ_new)[1])
        post_init = log(pdf(MvNormal(zeros(n_obs), HH/φ_new), error_init)[1] *
                        pdf(MvNormal(zeros(n_states), eye(n_states, n_states)), ϵ_init)[1])

        # Calculate α, probability of accepting the new particle
        α = exp(post_new - post_init)

        # Accept the particle with probability α
        if rand() < α
            # Accept and update particle
            s_out = s_new
            ϵ_out = ϵ_new
            accept += 1.
        else
            # Reject and keep particle unchanged
            s_out = s_non
            ϵ_out = ϵ_init
        end
        ϵ_init = ϵ_out
        s_non  = s_out
    end

    # Calculate acceptance rate
    accept_rate = accept/N_MH

    return s_out, ϵ_out, accept_rate
end
