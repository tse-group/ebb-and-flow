# DA protocol: proof-of-stake longest-chain

struct DABlock <: Block
    parent :: Union{DABlock, Nothing}
    payload :: Txs
end

DA_genesis = DABlock(nothing, "da-genesis")
genesis(::Type{DABlock}) = DA_genesis

struct DAClient
    id :: Int
    leafs :: Set{DABlock}
    rng_mining
end

function DAClient(id)
    return DAClient(
        id,
        Set{DABlock}([ genesis(DABlock) ]),
        MersenneTwister(RNG_SEED_POS_MINING + id),
    )
end

function tip(c :: DAClient)
    # prioritize adversarial over honest blocks
    leafs = sort(collect(c.leafs), by=b->(depth(b), startswith(b.payload, "adversarial")), rev=true)
    return leafs[1]
end

function confirmedtip(c :: DAClient)
    b = tip(c)
    for i in 1:k
        if b == genesis(DABlock)
            return b
        else
            b = b.parent
        end
    end
    return b
end

ledger(c :: DAClient) = ledger(confirmedtip(c))

function allblocks(c :: DAClient)
    blks = Set{DABlock}()
    for l in c.leafs
        union!(blks, chain(l))
    end
    return blks
end

function graphviz(c :: DAClient)
    str = ""
    str *= "\tsubgraph cluster_G_da {\n"
    str *= "\t\tstyle=filled;\n"
    str *= "\t\tcolor=lightgrey;\n"
    str *= "\t\tlabel=\"da-protocol\";\n"
    str *= "\t\tnode [shape=box,style=filled,color=white];\n"
    str *= "\n"
    for b in allblocks(c)
        str *= "\t\tdablk_$(objectid(b)) [label=\"$(b.payload)\"];\n"
    end
    str *= "\n"
    for b in allblocks(c)
        if b !== genesis(DABlock)
            str *= "\t\tdablk_$(objectid(b)) -> dablk_$(objectid(b.parent));\n"
        end
    end
    str *= "\t}\n"
    return str
end

struct DAMsgNewBlock <: Msg
    t :: Int
    id :: Int
    block :: DABlock
end

function slot!(c :: DAClient, t, msgs_out, msgs_in; role=:honest)
    for m in msgs_in
        if m isa DAMsgNewBlock
            setdiff!(c.leafs, [m.block.parent])
            push!(c.leafs, m.block)
        end
    end

    if rand(c.rng_mining) <= prob_pos_mining_success_per_slot
        # @show t, "DAClient", c.id, "mining lottery success"
        if role == :honest
            new_dablock = DABlock(tip(c), "t=$(t),id=$(c.id)")
        else #if role == :adversarial
            new_dablock = DABlock(tip(c), "adversarial:t=$(t),id=$(c.id)")
        end
        push!(msgs_out, DAMsgNewBlock(t, c.id, new_dablock))
        # @show new_dablock
    end
end
