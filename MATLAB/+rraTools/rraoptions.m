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
    end
    methods
        function obj = rraoptions(starttime,endtime,bForceset,bAdjustCOM,...
                comBody,trialpath,modelname,actuatorfile,extloadsetup,...
                kinfile,taskfile,resultspath,outname,rrasetupfile)
            
            obj.starttime = starttime;
            obj.endtime = endtime;
            obj.bForceset = bForceset;
            obj.bAdjustCOM = bAdjustCOM;
            obj.comBody = comBody;
            obj.trialpath = trialpath;
            obj.modelname = modelname;
            obj.actuatorfile = actuatorfile;
            obj.extloadsetup = extloadsetup;
            obj.kinfile = kinfile;
            obj.taskfile = taskfile;
            obj.resultspath = resultspath;
            obj.outname = outname;
            obj.rrasetupfile = rrasetupfile;
        end
    end   
end