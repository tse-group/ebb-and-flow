# P protocol: partially synchronous Streamlet

struct PBlock <: Block
    parent :: Union{PBlock, Nothing}
    epoch :: Int
    payload :: DABlock
end

P_genesis = PBlock(nothing, -1, genesis(DABlock))
genesis(::Type{PBlock}) = P_genesis

function epoch(t)
    return t ÷ (2*Δ_bft)
end

function leader(t)
    e = epoch(t)
    rng = MersenneTwister(RNG_SEED_BFT_LEADER + e)
    return rand(rng, 1:n)
end

mutable struct PClient
    id :: Int
    client_da :: DAClient    
    leafs :: Set{PBlock}
    votes :: Dict{PBlock,Set{Int}}
    current_epoch_proposal :: Union{PBlock, Nothing}
end

function PClient(id, client_da)
    return PClient(
        id,
        client_da,
        Set{PBlock}([ genesis(PBlock) ]),
        Dict{PBlock,Set{Int}}(),
        nothing,
    )
end

function isnotarized(c :: PClient, blk)
    if blk == genesis(PBlock)
        return true
    end

    if length(c.votes[blk]) >= n*2/3
        return true
    end

    return false
end

function lastnotarized(c :: PClient, blk)
    while !isnotarized(c, blk)
        blk = blk.parent
    end
    return blk
end

function tip(c :: PClient)
    best_block = genesis(PBlock)
    best_depth = depth(best_block)

    for l in c.leafs
        l = lastnotarized(c, l)
        if depth(l) > best_depth
            best_block = l
            best_depth = depth(l)
        end
    end

    return best_block
end

function finalizedtip(c :: PClient)
    best_block = genesis(PBlock)
    best_depth = depth(best_block)

    # for l in c.leafs
    for l in sort(collect(c.leafs), by=l->depth(l), rev=true)
        while depth(l) > 3 && depth(l) > best_depth
            b0 = l.parent.parent
            b1 = l.parent
            b2 = l

            if isnotarized(c, b0) && isnotarized(c, b1) && isnotarized(c, b2) && (b0.epoch == b2.epoch - 2) && (b1.epoch == b2.epoch - 1) && depth(b1) > best_depth
                best_block = b1
                best_depth = depth(b1)
                break
            end
            
            l = l.parent
        end
    end

    return best_block
end

ledger(c :: PClient) = ledger(finalizedtip(c))

function allblocks(c :: PClient)
    blks = Set{PBlock}()
    for l in c.leafs
        union!(blks, chain(l))
    end
    return blks
end

function graphviz(c :: PClient)
    str = ""
    str *= "\tsubgraph cluster_G_p {\n"
    str *= "\t\tstyle=filled;\n"
    str *= "\t\tcolor=lightgrey;\n"
    str *= "\t\tlabel=\"p-protocol\";\n"
    str *= "\t\tnode [shape=box,style=filled,color=white];\n"
    str *= "\n"
    for b in allblocks(c)
        if b !== genesis(PBlock)
            str *= "\t\tpblk_$(objectid(b)) [label=\"e=$(b.epoch),votes=$(length(c.votes[b]))\"];\n"
        else
            str *= "\t\tpblk_$(objectid(b)) [label=\"p-genesis\"];\n"
        end
    end
    str *= "\n"
    for b in allblocks(c)
        if b !== genesis(PBlock)
            str *= "\t\tpblk_$(objectid(b)) -> pblk_$(objectid(b.parent));\n"
        end
    end
    str *= "\n"
    for b in allblocks(c)
        str *= "\t\tpblk_$(objectid(b)) -> dablk_$(objectid(b.payload));\n"
    end
    str *= "\t}\n"
    return str
end

struct PMsgProposal <: Msg
    t :: Int
    id :: Int
    block :: PBlock
end

struct PMsgVote <: Msg
    t :: Int
    id :: Int
    block :: PBlock
end

function slot!(c :: PClient, t, msgs_out, msgs_in)
    for m in msgs_in
        if m isa PMsgProposal
            setdiff!(c.leafs, [m.block.parent])
            push!(c.leafs, m.block)

            c.votes[m.block] = Set{Int}()

            if m.block.epoch == epoch(t) && c.current_epoch_proposal === nothing
                c.current_epoch_proposal = m.block
            end
        end
    end
    
    for m in msgs_in
        if m isa PMsgVote
            push!(c.votes[m.block], m.id)
        end
    end

    if t % (2*Δ_bft) == 0
        c.current_epoch_proposal = nothing

        if leader(t) == c.id
            # @show t, "PClient", c.id, "leading epoch"
            new_pblock = PBlock(tip(c), epoch(t), confirmedtip(c.client_da))
            push!(msgs_out, PMsgProposal(t, c.id, new_pblock))
            # @show new_pblock
        end

    elseif t % (2*Δ_bft) == Δ_bft
        if c.current_epoch_proposal !== nothing
            push!(msgs_out, PMsgVote(t, c.id, c.current_epoch_proposal))
        end

    end
end
