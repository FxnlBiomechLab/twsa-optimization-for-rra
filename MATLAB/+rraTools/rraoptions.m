classdef rraoptions
    properties
        starttime
        endtime
        bForceset
        bAdjustCOM
        comBody
        trialpath
        modelname
        actuatorfile
        extloadsetup
        kinfile
        taskfile
        resultspath
        outname
        rrasetupfile
        LPhz
    end
    methods
        function obj = rraoptions(trialpath,modelname,actuatorfile,...
                extloadsetup,kinfile,taskfile,resultspath,outname,...
                rrasetupfile)
            
            obj.starttime = 0;
            obj.endtime = 0;
            obj.bForceset = true;
            obj.bAdjustCOM = true;
            obj.comBody = "torso";
            obj.trialpath = trialpath;
            obj.modelname = modelname;
            obj.actuatorfile = actuatorfile;
            obj.extloadsetup = extloadsetup;
            obj.kinfile = kinfile;
            obj.taskfile = taskfile;
            obj.resultspath = resultspath;
            obj.outname = outname;
            obj.rrasetupfile = rrasetupfile;
            obj.LPhz = -1;
        end
    end   
end