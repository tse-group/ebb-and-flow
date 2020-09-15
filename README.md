# Ebb-and-Flow Protocols: A Resolution of the Availability-Finality Dilemma

This repository contains the source code for the simulations of ebb-and-flow protocols presented in [Ebb-and-Flow].
For the source code of the attack presented in [Ebb-and-Flow] on the Gasper consensus protocol, please see: [https://github.com/tse-group/gasper-attack](https://github.com/tse-group/gasper-attack)


## Simulation of Snap-and-Chat Protocol

We simulate a snap-and-chat protocol constructed with Sleepy and Streamlet as constituent protocols, in the four scenarios described in [Ebb-and-Flow]:

* Figure 2: Overview in the introduction. Code: `006-simulation-04-overview-01.jl`. Results: `sim-04.dat`, `sim-04-phases.dat`.
* Figure 8: Dynamic participation. Code: `004-simulation-03-dynamic-participation-01.jl`. Results: `sim-03.dat`.
* Figure 9: Intermittent network partitions. Code: `003-simulation-01-network-partitions-01.jl`. Results: `sim-01.dat`, `sim-01-phase*.dat`.
* Figure 10: Convergence after network partition and/or low participation. Code: `005-simulation-02-convergence-01.jl`. Results: `sim-02.dat`, `sim-02-phases.dat`.

The simulation is implemented in the [Julia programming language](https://julialang.org/).
The simulation code is structured as follows:

* The main `.jl` file corresponding to the respective scenario contains the parameters of the scenario as well as the overall logic simulating the communication between participants, network partitions, dynamic participation, etc.
* `Basics.jl`: Contains some constants as well as generic operations on blocks and blockchains.
* `ProtocolDA.jl`: Implementation of Sleepy.
* `ProtocolP.jl`: Implementation of Streamlet.
* `Validators.jl`: Composition of Sleepy and Streamlet, as well as adversarial validator behavior.

To reproduce the Julia runtime environment (for Julia version 1.4.0), consult `Manifest.toml` and `Project.toml`.


## References

* [Ebb-and-Flow]<br/>
  **Ebb-and-Flow Protocols: A Resolution of the Availability-Finality Dilemma**<br/>
  Joachim Neu, Ertem Nusret Tas, David Tse<br/>
  [arXiv:2009.04987](https://arxiv.org/abs/2009.04987)



