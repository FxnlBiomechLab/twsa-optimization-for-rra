# rra-optimization
An evolutionary algorithm-based optimization for tracking weights in the OpenSim Residual Reduction Algorithm (RRA).

RRA-optimization tools written in python is contained in the class definition script "reduceresiduals.py". 

Class: rrasetup - returns an object initialized with file tags and folder paths specific to a single motion trial/simulation. This object posesses several methods to perform residual reduction steps as needed.
Methods: 
    1. writeRRATool() - short helper function that prints the xml setup file for RRA using determined settings
    2. initialRRA() - optional arguments: "createTasks", "createReserves", "createExtLoads" all boolean with default to true. This method performs the first iteration of RRA on a  participant scaled model. 
    3. runMassItrsRRA() - Use after the initial RRA iteration to perform model mass adjustments until the detected mass change is less than 0.001 kg. Maximum number of iterations is 10.
    4. adjMass() - short helper function called by "initialRRA" and "runMassItrsRRA" to make the recommended mass adjustments printed in the RRA log file. 
    5. createReservesFile() - optional arguments: "skip_coords" a list of strings specifying any coordinates to not actuate (will be given an optimal force of 1), "OptimalForce" a numeric input to specify the optimal force for all reserves (default is 1600)
    6. createTasksFile() - optional arguments: "skip_coords" a list of strings specifying coordinates that will not be tracked (which are otherwise unconstrained), "Kp" numeric value for proportional gain of the tracking weight controller (default = 1600), "UniformWeights" a boolean to either use equal weights for all tasks (default = True), or to use stronger weights for certain coordinates (False), "UserWeights" future incorporation will allow use to specify any weights using name value pairs.
    7. createExtLoads() - short helper that prints the xml external loads configuration file.
    8. optimizeTrackingWeights() - Performs the tracking weight optimization algorithm using the mass adjusted model. Optional arguments: "min_itrs" integer to specify a minimum number of iterations to use (default = 25), "max_itrs" integer to specify a maximum number of iterations (default = 75), "fcn_threshold" numeric input to specify target cost function value for good enough convergence, "wRes" numeric multiplier for the residual cost term (default = 2), "wErr" numeric multiplier for the tracking errors cost term (default = 1), "pRes" numeric polynomial power for the residual cost term, "pErr" polynomial power for the tracking errors cost term.