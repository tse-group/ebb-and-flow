# validators

abstract type Validator end

struct HonestValidator <: Validator
    id :: Int
    client_da :: DAClient
    client_p :: PClient
end

function HonestValidator(id)
    client_da = DAClient(id)
    client_p = PClient(id, client_da)
    return HonestValidator(
        id,
        client_da,
        client_p,
    )
end

function slot!(v :: HonestValidator, t, msgs_out, msgs_in)
    slot!(v.client_da, t, msgs_out, msgs_in)
    slot!(v.client_p, t, msgs_out, msgs_in)
end

function graphviz(v :: HonestValidator)
    str = ""
    str *= "digraph G {\n"
    str *= "\trankdir=BT;\n"
    str *= "\n"
    str *= graphviz(v.client_da)
    str *= "\n"
    str *= graphviz(v.client_p)
    str *= "}"
    return str
end

function sanitize(lst :: Vector{String})
    out = Vector{String}()
    for l in lst
        if !(l in out)
            push!(out, l)
        end
    end
    return out
end

function Lp(v :: HonestValidator)
    return sanitize(vcat(ledger.(ledger(v.client_p))...))
end

function Lda(v :: HonestValidator)
    return sanitize(vcat(Lp(v), ledger(v.client_da)))
end


struct AdversarialValidator <: Validator
    id :: Int
    client_da :: DAClient
end

function AdversarialValidator(id)
    client_da = DAClient(id)
    return AdversarialValidator(
        id,
        client_da,
    )
end

function slot!(v :: AdversarialValidator, t, msgs_out, msgs_in)
    # adversary does not participate in simulations 1 and 3
end

function slot!(v :: AdversarialValidator, t, msgs_out_private_adversarial, msgs_out_rush_honest, msgs_in, msgs_in_rush_honest)
    # adversary produces a private competing longest chain in simulation 2

    slot!(v.client_da, t, msgs_out_private_adversarial, vcat(msgs_in, msgs_in_rush_honest); role=:adversarial)


    if v.id == n
        # the last adversarial validator is responsible for releasing pre-mined blocks
        # to displace honest blocks

        d = -1

        for m in msgs_in_rush_honest
            if m isa DAMsgNewBlock
                d = max(d, depth(m.block))
            end
        end

        if d > -1
            # a new honest block was produced in this slot
            # at depth d, we need to counter it with an adversarial block if possible

            blk = tip(v.client_da)
            
            if depth(blk) < d
                # no deeper adversarial pre-mined block available,
                # nothing the adversary can do to displace this block

            else
                # find the block of suitable depth to release
                while depth(blk) > d
                    blk = blk.parent
                end

                # release block
                push!(msgs_out_rush_honest, DAMsgNewBlock(t, v.client_da.id, blk))

            end
        end
    end
end

function graphviz(v :: AdversarialValidator)
    str = ""
    str *= "digraph G {\n"
    str *= "\trankdir=BT;\n"
    str *= "\n"
    str *= graphviz(v.client_da)
    str *= "}"
    return str
end

function Lda(v :: AdversarialValidator)
    return sanitize(ledger(v.client_da))
end
