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
T_partitions = [(10*minute, 20*minute), (30*minute, 45*minute),]

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


# PARTITIONS

function getpartition(t)
    for (idx, (T_part_start, T_part_end)) in enumerate(T_partitions)
        if T_part_start <= t < T_part_end
            return (true, idx)
        end
    end
    return (false, -1)
end

function ispartitioned(t)
    return getpartition(t)[1]
end


# MAIN LOOP

validators = [ id <= (n-f) ? HonestValidator(id) : AdversarialValidator(id) for id in 1:n ]

validators_hon = validators[1:(n-f)]
validators_A = validators[1:((n-f)÷3*2)]
validators_B = validators[((n-f)÷3*2+1):(n-f)]

msgs_inflight_A = Dict{Int,Set{Msg}}()
msgs_inflight_B = Dict{Int,Set{Msg}}()

println(join(["t", "l_Lp", "l_Lp_A", "l_Lp_B", "l_Lda", "l_Lda_A", "l_Lda_B"], " "))


for t in 0:(T_end - 1)
    # @show t

    for (idx, (T_part_start, T_part_end)) in enumerate(T_partitions)
        if t == T_part_start
            # @show t, "start of partition", idx
            println("# t=$(t): start of partition $(idx)")
        elseif t == T_part_end
            # @show t, "end of partition", idx
            println("# t=$(t): end of partition $(idx)")
        end
    end

    # prepare msg queues
    msgs_out_A = Set{Msg}()
    msgs_out_B = Set{Msg}()
    msgs_in_A = get(msgs_inflight_A, t, Set{Msg}())
    msgs_in_B = get(msgs_inflight_B, t, Set{Msg}())


    # compute validator actions for this slot    
    for v in validators_A
        slot!(v, t, msgs_out_A, msgs_in_A)
    end
    for v in validators_B
        slot!(v, t, msgs_out_B, msgs_in_B)
    end


    # msg delivery, respecting periods of intermittent partitions
    if ispartitioned(t)
        T_part_end = T_partitions[getpartition(t)[2]][2]
        t_delivery_inter = max(t + Δ, T_part_end)
        t_delivery_intra = t + Δ
    else
        t_delivery_inter = t + Δ
        t_delivery_intra = t + Δ
    end

    msgs_inflight_A[t_delivery_inter] = get(msgs_inflight_A, t_delivery_inter, Set{Msg}())
    msgs_inflight_B[t_delivery_inter] = get(msgs_inflight_B, t_delivery_inter, Set{Msg}())
    msgs_inflight_A[t_delivery_intra] = get(msgs_inflight_A, t_delivery_intra, Set{Msg}())
    msgs_inflight_B[t_delivery_intra] = get(msgs_inflight_B, t_delivery_intra, Set{Msg}())

    union!(msgs_inflight_A[t_delivery_inter], msgs_out_B)
    union!(msgs_inflight_B[t_delivery_inter], msgs_out_A)
    union!(msgs_inflight_A[t_delivery_intra], msgs_out_A)
    union!(msgs_inflight_B[t_delivery_intra], msgs_out_B)


    if t % 15*second == 0
        # log ledger lengths
        l_Lp_A = minimum([ length(Lp(v))-1 for v in validators_A ])
        l_Lp_B = minimum([ length(Lp(v))-1 for v in validators_B ])
        l_Lda_A = minimum([ length(Lda(v))-1 for v in validators_A ])
        l_Lda_B = minimum([ length(Lda(v))-1 for v in validators_B ])
        l_Lp = min(l_Lp_A, l_Lp_B)
        l_Lda = min(l_Lda_A, l_Lda_B)

        println(join([t/second, l_Lp, l_Lp_A, l_Lp_B, l_Lda, l_Lda_A, l_Lda_B], " "))
        # @show t/second, l_Lp, l_Lp_A, l_Lp_B, l_Lda, l_Lda_A, l_Lda_B
    end
end


# DUMP FINAL NETWORK VIEW

network = HonestValidator(0)

for t in sort(collect(keys(msgs_inflight)))
    slot!(network, t, Set{Msg}(), msgs_inflight[t])
end

println(graphviz(network))

println(Lp(network))
println(Lda(network))
