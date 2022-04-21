# Tracking Weight Selection Algorithm (TWSA) Optimization for the OpenSim Residual Reduction Algorithm
OpenSim's Residual Reduction Algorithm (RRA) adjusts human movement simulations in order to improve dynamic consistency. Using RRA in a typical workflow involves iteratively hand-tuning tracking weights to achieve an optimal solution, which is a time-consuming process.

This software package automates the process of optimizing tracking weights. Optimization is performed using the Tracking Weight Selection Algorithm (TWSA), an evolutionary algorithm-based optimization. 

## How it works

Below is a brief description of the TWSA. For full details, refer to the [published paper](https://www.biorxiv.org/content/10.1101/2021.10.06.463431v1.full.pdf).
###  *Formulating the objective function*

The TWSA formulates an objective function as a weighted sum of the residual forces and kinematic errors:

![equation1](https://latex.codecogs.com/svg.image?W_{R}\sum_{i=1}^{m}(w_{i}R_{i})^{p_{R}}&plus;W_{E}\sum_{j=1}^{n}(w_{j}E_{j})^{p_{E}})

The relative penalty on residual forces and kinematic errors are controlled by the weights W<sub>R</sub> and W<sub>E</sub>, respectively. 

The terms R<sub>i</sub> and E<sub>j</sub> represent the root-mean-squared residual forces and kinematic errors, respectively. By default, the weights w<sub>i</sub> and w<sub>j</sub> are set to the inverse of the OpenSim-recommended maximum residual force or kinematic error. In other words, when the value of R<sub>i</sub> or E<sub>j</sub> is at the recommended limit, the term inside the parentheses will be 1. If the value drops below the recommended maximum, it will effectively disappear from the objective function. If it increases over the recommended maximum, it will rapidly "blow up" because of the exponents p<sub>R</sub> and p<sub>E</sub>. These terms act as barrier functions that try to force the residuals and errors to fall below the recommended maximum values. The severity of the penalty for exceeding those thresholds can be controlled by changing p<sub>R</sub> and p<sub>E</sub>.

### *Selecting tracking weights*

When running RRA in OpenSim, the user must select weights x<sub>j</sub> for each coordinate. Lower weights allow greater error, while higher weights reduce error in that coordinate.

The TWSA starts with uniform tracking weights set at 1. After each iteration of RRA, the RMS kinematic errors are evaluated against user-defined upper and lower bounds (separate from the objective function thresholds). For each RMS error value E<sub>j</sub>, E<sub>j</sub> < lower bound is considered "good", E<sub>j</sub> > upper bound is considered "bad", and E<sub>j</sub> in between the bounds is considered "ok". 

For each tracking weight, we create a perturbation parameter:

![equation2](https://latex.codecogs.com/svg.image?\tau_{j}=b^t)

Initially, b is set to 1.5. The exponent t is a randomly selected integer ranging from -2 to +2. For "good" RMS errors t is biased toward negative values (decreases the tracking weight), for "bad" RMS errors t is biased toward positive values (increase the tracking weight), and for "ok" values there is an equal chance of positive and negative values.

As an example, suppose we set the RMS pelvis x-translation error to be "good" if it is below 1cm and "bad" if it is above 3cm. We run the first iteration of RRA (default tracking weight = 1) and get an RMS error of 2.4cm, which falls in the "ok" range. We randomly select a value for t, and get t=1. We calculate a new tracking weight:

![equation3](https://latex.codecogs.com/svg.image?\newline&space;x_{j,new}=b^{t}x_{j,old}\newline&space;x_{j,new}=1.5^{1}*1=1.5)

So we've increased the tracking weight on the pelvis x-translation to 1.5. After performing the same process for the other tracking weights, we re-run RRA and determine if the new tracking weights improved the objective function or not.

## Code
Implementations of the TWSA are provided in Python and MATLAB. Instructions on how to run each package are provided in those directories.

We also provide a copy of publicly available data from Hamner et al. 2013 (https://simtk.org/projects/nmbl_running). These files provide the inputs for generating a simulation of human running, and can be used to test the TWSA. 

Hamner SR and Delp SL. Muscle contributions to fore-aft and vertical body mass center accelerations over a range of running speeds. Journal of Biomechanics; 46(4), 780-7. (2013)

**Note:** The files provided have been tested in OpenSim 4.3.
*(The MATLAB classes should work with OpenSim versions 3.3 through 4.3; however, the example OpenSim model files are specific to 4.x)*

## Acknowledgment
This code is provided under the permissive MIT license. You are free to use, modify, and redistribute it for any purpose. If you use this tool in your research, please cite the following paper:

Sturdy JT, Silverman AK, Pickle NT. Automated optimization of residual reduction algorithm parameters in opensim. Journal of Biomechanics. 2022 Apr 8:111087. https://doi.org/10.1101/2021.10.06.463431
