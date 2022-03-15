# Tracking Weight Selection Algorithm (TWSA) Optimization for the OpenSim Residual Reduction Algorithm
OpenSim's Residual Reduction Algorithm (RRA) adjusts human movement simulations in order to enhance dynamic consistency. Using RRA in a typical workflow involves iteratively hand-tuning tracking weights to achieve an optimal solution, which is a time-consuming process.

This software package automates the process of optimizing tracking weights. Optimization is performed using the Tracking Weight Selection Algorithm (TWSA), an evolutionary algorithm-based optimization. 

## Contents
Implementations of the TWSA are provided in Python and MATLAB. Instructions on how to run each package are provided in those directories.

We also provide a copy of publicly available data from Hamner et al. 2013 (https://simtk.org/projects/nmbl_running). These files provide the inputs for generating a simulation of human running, and can be used to test the TWSA. Hamner SR and Delp SL. Muscle contributions to fore-aft and vertical body mass center accelerations over a range of running speeds. Journal of Biomechanics; 46(4), 780-7. (2013)

**Note:** The files provided have been tested in OpenSim 4.3.

## Acknowledgment
This code is provided under the permissive MIT license. You are free to use, modify, and redistribute it for any purpose. If you use this tool in your research, please cite the following paper:

Sturdy JT, Silverman AK, Pickle NT. Automated optimization of residual reduction algorithm parameters in OpenSim. Preprint. https://doi.org/10.1101/2021.10.06.463431
