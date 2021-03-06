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
T_part_start = 1400*second   #10*minute
T_part_stop = 2000*second #30*minute

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

rng_da = MersenneTwister(RNG_SEED_DYNAMIC_PARTICIPATION + 1)

function da_tick!(vs_awake, vs_asleep)
    # for i in 1:3
        if length(vs_awake) == 60
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

validators_honest = validators[1:(n-f)]
validators_adversarial = validators[(n-f+1):n]

validators_awake = copy(validators_honest)
validators_asleep = []

validators_part1 = validators[1:(n-f)÷2]
validators_part2 = validators[((n-f)÷2+1):(n-f)]

msgs_inflight = Dict{Int,Dict{Validator,Vector{Msg}}}()
msgs_missed = Dict( v => Vector{Msg}() for v in validators )

liveness_phases = Vector{Tuple{Int,Float64,Int}}()
liveness_phase_start = nothing

println(join(["t", "l_Lp", "l_Lp_1", "l_Lp_2", "l_Lda", "l_Lda_1", "l_Lda_2", "l_awake", "l_asleep", "l_Lda_adv"], " "))


for t in 0:T_end
    # @show t

    da_tick!(validators_awake, validators_asleep)


    global liveness_phase_start
    if t % 15*second == 0
        if liveness_phase_start === nothing && length(validators_awake) >= 67
            liveness_phase_start = t
        elseif liveness_phase_start !== nothing && length(validators_awake) < 67 || t == T_end
            push!(liveness_phases, (liveness_phase_start, (liveness_phase_start + t)/2, t))
            liveness_phase_start = nothing
        end
    end


    # prepare msg queues
    msgs_in_all = get(msgs_inflight, t, Dict{Validator,Vector{Msg}}())
    msgs_out_part1 = Vector{Msg}()
    msgs_out_part2 = Vector{Msg}()


    # compute awake honest validator actions for this slot
    # collect messages missed by asleep validators
    for v in validators_honest
        msgs_in = get(msgs_in_all, v, Vector{Msg}())

        if v in validators_awake
            if v in validators_part1
                msgs_out = msgs_out_part1
            else #if v in validators_part2
                msgs_out = msgs_out_part2
            end

            slot!(v, t, msgs_out, vcat(msgs_missed[v], msgs_in))
            empty!(msgs_missed[v])

        else #if v in validators_asleep
            append!(msgs_missed[v], msgs_in)

        end
    end


    # msg delivery, respecting the partition
    if T_part_start <= t < T_part_stop
        t_delivery_inter = max(t + Δ, T_part_stop)
        t_delivery_intra = t + Δ
    else
        t_delivery_inter = t + Δ
        t_delivery_intra = t + Δ
    end

    msgs_inflight[t_delivery_inter] = get(msgs_inflight, t_delivery_inter, Dict( v => Vector{Msg}() for v in validators ))
    msgs_inflight[t_delivery_intra] = get(msgs_inflight, t_delivery_intra, Dict( v => Vector{Msg}() for v in validators ))

    for v in validators_part1
        append!(msgs_inflight[t_delivery_inter][v], msgs_out_part2)
        append!(msgs_inflight[t_delivery_intra][v], msgs_out_part1)
    end
    for v in validators_part2
        append!(msgs_inflight[t_delivery_inter][v], msgs_out_part1)
        append!(msgs_inflight[t_delivery_intra][v], msgs_out_part2)
    end


    # compute adversarial validator actions for this slot
    msgs_honest = vcat(msgs_out_part1, msgs_out_part2)
    msgs_out_rush_honest = Vector{Msg}()
    msgs_out_private_adversarial = Vector{Msg}()

    for v in validators_adversarial
        msgs_in = get(msgs_in_all, v, Vector{Msg}())
        slot!(v, t, msgs_out_private_adversarial, msgs_out_rush_honest, vcat(msgs_in), msgs_honest)
    end


    # msg delivery for adversarial msgs
    msgs_inflight[t + 1] = get(msgs_inflight, t + 1, Dict( v => Vector{Msg}() for v in validators ))

    for v in validators_honest
        prepend!(msgs_inflight[t + 1][v], msgs_out_rush_honest)
    end

    for v in validators_adversarial
        append!(msgs_inflight[t + 1][v], msgs_out_private_adversarial)
        append!(msgs_inflight[t + 1][v], msgs_out_rush_honest)
    end


    # log ledger lengths
    if t % 15*second == 0
        l_Lp_1 = minimum([ length(Lp(v))-1 for v in intersect(validators_awake, validators_part1) ])
        l_Lp_2 = minimum([ length(Lp(v))-1 for v in intersect(validators_awake, validators_part2) ])
        l_Lda_1 = minimum([ length(Lda(v))-1 for v in intersect(validators_awake, validators_part1) ])
        l_Lda_2 = minimum([ length(Lda(v))-1 for v in intersect(validators_awake, validators_part2) ])
        l_Lp = min(l_Lp_1, l_Lp_2)
        l_Lda = min(l_Lda_1, l_Lda_2)
        l_Lda_adv = minimum([ length(Lda(v))-1 for v in intersect(validators_adversarial) ])

        println(join([t/second, l_Lp, l_Lp_1, l_Lp_2, l_Lda, l_Lda_1, l_Lda_2, length(validators_awake), length(validators_asleep), l_Lda_adv], " "))
    end
end


println()

# DUMP Lp/Lda AS SEEN BY HONEST VALIDATOR IN PART1/PART2 AND ADVERSARY

println("Lp:")
println(Lp(validators_part1[1]))
println(Lp(validators_part2[1]))
# println(Lp(validators_adversarial[end]))
println()

println("Lda:")
println(Lda(validators_part1[1]))
println(Lda(validators_part2[1]))
println(Lda(validators_adversarial[end]))
println()

println("Blocktrees:")
println(graphviz(validators_part1[1]))
println(graphviz(validators_part2[1]))
println(graphviz(validators_adversarial[end]))

@show liveness_phases
println(join([ join(phase, "/") for phase in liveness_phases ], ", "))
