# rra-optimization
An evolutionary algorithm-based optimization for tracking weights in the OpenSim Residual Reduction Algorithm (RRA).

RRA-optimization tools written in python is contained in the class definition script "reduceresiduals.py". 

### Class: rrasetup 
Calling the constructor **"obj = rrasetup(trialpath, participant, condition, mass)"** returns an object initialized with file tags and folder paths specific to a single motion trial/simulation. This object posesses several methods to perform residual reduction steps as needed.
### Methods: 
1. **initialRRA()** - optional arguments: "createTasks", "createReserves", "createExtLoads" all boolean with default to true. This method performs the first iteration of RRA on a  participant scaled model. 

2. **runMassItrsRRA()** - Use after the initial RRA iteration to perform model mass adjustments until the detected mass change is less than 0.001 kg. Maximum number of iterations is 10.

3. **optimizeTrackingWeights()** - Performs the tracking weight optimization algorithm using the mass adjusted model. Optional arguments: "min_itrs" integer to specify a minimum number of iterations to use (default = 25), "max_itrs" integer to specify a maximum number of iterations (default = 75), "fcn_threshold" numeric input to specify target cost function value for good enough convergence, "wRes" numeric multiplier for the residual cost term (default = 2), "wErr" numeric multiplier for the tracking errors cost term (default = 1), "pRes" numeric polynomial power for the residual cost term, "pErr" polynomial power for the tracking errors cost term.

* **writeRRATool()** - short helper function that prints the xml setup file for RRA using determined settings

* **adjMass()** - short helper function called by "initialRRA" and "runMassItrsRRA" to make the recommended mass adjustments printed in the RRA log file. 

* **createReservesFile()** - optional arguments: "skip_coords" a list of strings specifying any coordinates to not actuate (will be given an optimal force of 1), "OptimalForce" a numeric input to specify the optimal force for all reserves (default is 1600)

* **createTasksFile()** - optional arguments: "skip_coords" a list of strings specifying coordinates that will not be tracked (which are otherwise unconstrained), "Kp" numeric value for proportional gain of the tracking weight controller (default = 1600), "UniformWeights" a boolean to either use equal weights for all tasks (default = True), or to use stronger weights for certain coordinates (False), "UserWeights" future incorporation will allow use to specify any weights using name value pairs.

* **createExtLoads()** - short helper that prints the xml external loads configuration file.

* Additional internal helpers and nested classes are defined, but not described here.

### Class: rrafiles
Only a constructor method exists for this class. The returned rrafiles object has the following properties.
* **trialpath** - system path to the trial folder containing the scaled model, motion, and grf files.
* **resultspath** - system path to initial RRA results location. By default is specified as *trialpath\RRA_initial*
* **adjresultspath** - system path to the mass iterations results. By default specified as *trialpath\RRA_adjMass*
* **optpath** - system path to tracking weight optimization folder. By default specified as *trialpath\RRA_optWeights*
* **finalpath** - system path to final optimized results. By default specied as *trialpath\RRA_Final*
* **modelname** - filename of participant scaled model. Uses input arguments to construct. *(participant)_(condition).osim*
* **outname** - filename of model output from RRA tool with center of mass adjustments performed. Appends "_adjMass" to modelname
* **adjname** - filename of model after mass adjustments are applied. Appends "_adj" to modelname
* **optname** - filename of model after tracking weight optimizations. Appends "_Final" to modelname
* **kinfile** - filename of IK results. Default is *"Visual3d_SIMM_input.mot"*
* **grffile** - filename of ground reaction forces. Default is *"Visual3d_SIMM_grf.mot"*
* **extloadsetup** - filename where external loads specifications will be written. Default "External_Loads_grf.xml"
* **actuatorfile** - filename to write reserver actuators. Default is "RRA_reserves.xml"
* **taskfile** - filename to write tracking tasks. Default is *"RRA_tasks.xml"*
* **rrasetupfile** - filename to initial RRA tool setup xml. Default is *"RRA_setup.xml"*
* **masssetupfile** - filename to RRA tool setup xml for mass iterations. Default is *"RRA_Setup_massItrs.xml"* 
* genericsetup - unused. Will be removed.

### Class: rraoptions