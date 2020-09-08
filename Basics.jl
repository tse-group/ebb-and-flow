# constants

RNG_SEED_POS_MINING = 2342
RNG_SEED_BFT_LEADER = 4242
RNG_SEED_DYNAMIC_PARTICIPATION = 2121


# values derived from parameters

λ0 = λ / n
prob_pos_mining_success_per_slot = λ0 / second


# basic types

const Txs = String
abstract type Block end
abstract type Msg end

depth(b) = b.parent === nothing ? 0 : depth(b.parent) + 1
chain(b) = b.parent === nothing ? [b,] : vcat(chain(b.parent), [b,])
ledger(b) = b.parent === nothing ? [b.payload,] : vcat(ledger(b.parent), [b.payload,])
