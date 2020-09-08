#! /usr/bin/env julia

# JULIA ENVIRONMENT

using Pkg
Pkg.activate(".")

using Random
using DataStructures


# PARAMETERS

# network simulation
second = 1
minute = 60*second
hour = 60*minute

Δ = 1*second
T_end = 60*minute

# adversarial/honest validators
n = 100
f = 25

# da protocol
λ = 0.1
k = 20

# p protocol
Δ_bft = 5 * Δ


# IMPLEMENTATION

include("Basics.jl")
include("ProtocolDA.jl")
include("ProtocolP.jl")
include("Validators.jl")


# DYNAMIC AVAILABILITY

rng_da = MersenneTwister(RNG_SEED_DYNAMIC_PARTICIPATION)

function da_tick!(vs_awake, vs_asleep)
    # for i in 1:3
        if length(vs_awake) == 2*f+1
            # can only wake one up
            dir = rand(rng_da, (:toawake, :nothing))
        elseif length(vs_awake) == n-f
            # can only put one to sleep
            dir = rand(rng_da, (:nothing, :toasleep))
        else
            # flip a coin
            dir = rand(rng_da, (:toawake, :toasleep))
        end

        if dir == :toawake
            shuffle!(rng_da, vs_asleep)
            push!(vs_awake, pop!(vs_asleep))
        elseif dir == :toasleep
            shuffle!(rng_da, vs_awake)
            push!(vs_asleep, pop!(vs_awake))
        else #if dir == :nothing
            # nop
        end
    # end
end


# MAIN LOOP

validators = [ id <= (n-f) ? HonestValidator(id) : AdversarialValidator(id) for id in 1:n ]
validators_awake = validators[1:((n-f)÷5*4)]
validators_asleep = validators[((n-f)÷5*4+1):(n-f)]

msgs_inflight = Dict{Int,Vector{Msg}}()
msgs_missed = Dict( v => Vector{Msg}() for v in validators )

println(join(["t", "l_Lp", "l_Lda", "l_awake", "l_asleep"], " "))


for t in 0:T_end
    # @show t

    da_tick!(validators_awake, validators_asleep)


    # prepare msg queues
    msgs_inflight[t + Δ] = Vector{Msg}()
    msgs_out = msgs_inflight[t + Δ]
    msgs_in = get(msgs_inflight, t, Vector{Msg}())


    # compute awake validator actions for this slot
    # collect messages missed by asleep validators
    for v in validators
        if v in validators_awake
            slot!(v, t, msgs_out, vcat(msgs_missed[v], msgs_in))
            empty!(msgs_missed[v])
        else #if v in validators_asleep
            msgs_missed[v] = vcat(msgs_missed[v], msgs_in)
        end
    end


    if t % 15*second == 0
        # log ledger lengths
        l_Lp = minimum([ length(Lp(v))-1 for v in validators_awake ])
        l_Lda = minimum([ length(Lda(v))-1 for v in validators_awake ])

        println(join([t/second, l_Lp, l_Lda, length(validators_awake), length(validators_asleep)], " "))
    end
end


# # DUMP FINAL NETWORK VIEW

# network = HonestValidator(0)

# for t in sort(collect(keys(msgs_inflight)))
#     slot!(network, t, Set{Msg}(), msgs_inflight[t])
# end

# println(graphviz(network))

# println(Lp(network))
# println(Lda(network))
