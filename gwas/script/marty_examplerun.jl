# Interactive session for running on Colonial One
#
# Read configuration file to get directory locations to add to LOAD_PATH
# Other startup parameters might also be necessary. The top level variable "ini",
# defined in .juliarc is accessible to the REPL

# Based on the values in the application conf file, LOAD_PATH has several directories
# added to it in .juliarc.jl. (.juliarc.jl is run at Julia startup.)
# The conf file to use is specified in the "JULIA_APP_BOOTSTRAP",
# which is set in .bashrc. .juliarc sets a variable, ini, which is available to the REPL.
# ini contains the configuration settings set in the JULIA_APP_BOOTSTRAP conf file.


# Julia routines for Slurm processing
require ("slurm_utility.jl")
require ("mpstat_parse.jl")
using SlurmUtility


#
#       Add processors
# get compute nodes assigned to job, one with master, one w/o
# TODO(mwh): Make loop to create multiple processes on each node, including local one
#
nodelist = get_slurm_nodelist()
addprocs(nodelist) # this will add one proc per node

# These modules might have been loaded at startup, but need to be again
# after remote nodes are added
reload("slurm_utility.jl"); @everywhere using SlurmUtility
require("mpstat_parse.jl"); @everywhere using UtilModule
require("t.jl"); @everywhere using T
@everywhere using UtilModule # The using should happen after procs are setup

remote_nodelist = remove_master_from_nodelist(nodelist)
# Add some local and some remote processes
@time lp = addprocs(5)
rnl = [remote_nodelist, remote_nodelist, remote_nodelist, remote_nodelist, remote_nodelist]
@time rp = addprocs(rnl)

#
# @everywhere macro isn't clever enough, to do variable substitution locally
# TODO(mwh) Build wrapper for @everywhere macro that does local variable substitution
#
@time @everywhere include("/home/mhimmelstein/CodeandSampleData/current/StatGenDataDboot2.jl")
@everywhere include("$(include_dir)StatGenDataDboot2.jl")

@everywhere using StatGenDataD

@time kdat=dGenDat("$(app_dir)smallAZdatasets/az12000snp")
phecorefile ="$(app_dir)smallAZdatasets/CSFSep06_2013_v1.1coreNAapo.txt"
#this joins the phenotype data with the genotype data in the GenDat type on each process in the .fam field
@time addphe!(phecorefile,kdat);
@time updatecounts!(kdat);
missingthreshhold!(0.05,kdat);
MAFthreshhold!(0.01,kdat);

for i=1:length(kdat.refs)
	@spawnat kdat.refs[i].where fetch(kdat.refs[i]).fam[:Series]=PooledDataArray(fetch(kdat.refs[i]).fam[:Series])
	@spawnat kdat.refs[i].where (for k=1:1:size(fetch(kdat.refs[i]).fam,1) fetch(kdat.refs[i]).fam[:CDR12].data[k] -=1 end)
end

form_tau_ab42=lsubtau~age+gender+Series+PC1+PC2+APOE2+APOE4+lsubAb42+snp+lsubAb42&snp
form_ptau_ab42=lsubptau~age+gender+Series+PC1+PC2+APOE2+APOE4+lsubAb42+snp+lsubAb42&snp
form_cdr_ab42=CDR12~age+gender+Series+PC1+PC2+APOE2+APOE4+lsubAb42+snp+lsubAb42&snp

@time ptau_ab42add12000=gwLM(form_ptau_ab42,1,kdat,responsetype=:linear);

writeresults("$(app_dir)ptau_ab42addrqtl12000.txt",ptau_ab42add12000)