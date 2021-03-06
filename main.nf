#!/usr/bin/env nextflow
/*
========================================================================================
                         lifebit-ai/xxxx
========================================================================================
lifebit-ai/xxxx
 #### Homepage / Documentation
https://github.com/xxxx
----------------------------------------------------------------------------------------
*/

// Help message

def helpMessage() {
    log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run main.nf --bams sample.bam [Options]
    
    Inputs Options:
    --input         Input file

    Resource Options:
    --max_cpus      Maximum number of CPUs (int)
                    (default: $params.max_cpus)  
    --max_memory    Maximum memory (memory unit)
                    (default: $params.max_memory)
    --max_time      Maximum time (time unit)
                    (default: $params.max_time)
    See here for more info: https://github.com/lifebit-ai/hla/blob/master/docs/usage.md
    """.stripIndent()
}

// Show help message
if (params.help) {
  helpMessage()
  exit 0
}



/*--------------------------------------------------------
  Defining and showing header with all params information 
----------------------------------------------------------*/

// Header log info

def summary = [:]

if (workflow.revision) summary['Pipeline Release'] = workflow.revision

summary['Output dir']                                  = params.outdir
summary['Launch dir']                                  = workflow.launchDir
summary['Working dir']                                 = workflow.workDir
summary['Script dir']                                  = workflow.projectDir
summary['User']                                        = workflow.userName
summary['mutational-signature-nf outptut path']        = params.sigfit_results_dir
summary['organ']                                       = params.organ

log.info summary.collect { k,v -> "${k.padRight(18)}: $v" }.join("\n")
log.info "-\033[2m--------------------------------------------------\033[0m-"



/*-------------------------------------------------
  Setting up introspection variables and channels  
----------------------------------------------------*/

// Importantly, in order to successfully introspect:
// - This needs to be done first `main.nf`, before any (non-head) nodes are launched. 
// - All variables to be put into channels in order for them to be available later in `main.nf`.

ch_repository         = Channel.of(workflow.manifest.homePage)
ch_commitId           = Channel.of(workflow.commitId ?: "Not available is this execution mode. Please run 'nextflow run ${workflow.manifest.homePage} [...]' instead of 'nextflow run main.nf [...]'")
ch_revision           = Channel.of(workflow.manifest.version)

ch_scriptName         = Channel.of(workflow.scriptName)
ch_scriptFile         = Channel.of(workflow.scriptFile)
ch_projectDir         = Channel.of(workflow.projectDir)
ch_launchDir          = Channel.of(workflow.launchDir)
ch_workDir            = Channel.of(workflow.workDir)
ch_userName           = Channel.of(workflow.userName)
ch_commandLine        = Channel.of(workflow.commandLine)
ch_configFiles        = Channel.of(workflow.configFiles)
ch_profile            = Channel.of(workflow.profile)
ch_container          = Channel.of(workflow.container)
ch_containerEngine    = Channel.of(workflow.containerEngine)



/*----------------------------------------------------------------
  Setting up additional variables used for documentation purposes  
-------------------------------------------------------------------*/

Channel
    .of(params.raci_owner)
    .set { ch_raci_owner } 

Channel
    .of(params.domain_keywords)
    .set { ch_domain_keywords }



/*----------------------
  Setting up input data  
-------------------------*/

// Define channels from repository files

projectDir = workflow.projectDir

ch_signatureFitAggregate_script = Channel.fromPath("${projectDir}/bin/AggregationScripts/signatureFitAggregate")
ch_report_dir = Channel.value(file("${projectDir}/bin/report"))

// Define Channels from input
sigfit_results_dir = params.sigfit_results_dir.split(',').collect()
sigfit_results_dir_ch = Channel
                        .fromPath(sigfit_results_dir)

/*-----------
  Processes  
--------------*/

// Do not delete this process
// Create introspection report

process obtain_pipeline_metadata {
  publishDir "${params.tracedir}", mode: "copy"

  input:
  val repository from ch_repository
  val commit from ch_commitId
  val revision from ch_revision
  val script_name from ch_scriptName
  val script_file from ch_scriptFile
  val project_dir from ch_projectDir
  val launch_dir from ch_launchDir
  val work_dir from ch_workDir
  val user_name from ch_userName
  val command_line from ch_commandLine
  val config_files from ch_configFiles
  val profile from ch_profile
  val container from ch_container
  val container_engine from ch_containerEngine
  val raci_owner from ch_raci_owner
  val domain_keywords from ch_domain_keywords

  output:
  file("pipeline_metadata_report.tsv") into ch_pipeline_metadata_report
  
  shell:
  '''
  echo "Repository\t!{repository}"                  > temp_report.tsv
  echo "Commit\t!{commit}"                         >> temp_report.tsv
  echo "Revision\t!{revision}"                     >> temp_report.tsv
  echo "Script name\t!{script_name}"               >> temp_report.tsv
  echo "Script file\t!{script_file}"               >> temp_report.tsv
  echo "Project directory\t!{project_dir}"         >> temp_report.tsv
  echo "Launch directory\t!{launch_dir}"           >> temp_report.tsv
  echo "Work directory\t!{work_dir}"               >> temp_report.tsv
  echo "User name\t!{user_name}"                   >> temp_report.tsv
  echo "Command line\t!{command_line}"             >> temp_report.tsv
  echo "Configuration file(s)\t!{config_files}"    >> temp_report.tsv
  echo "Profile\t!{profile}"                       >> temp_report.tsv
  echo "Container\t!{container}"                   >> temp_report.tsv
  echo "Container engine\t!{container_engine}"     >> temp_report.tsv
  echo "RACI owner\t!{raci_owner}"                 >> temp_report.tsv
  echo "Domain keywords\t!{domain_keywords}"       >> temp_report.tsv

  awk 'BEGIN{print "Metadata_variable\tValue"}{print}' OFS="\t" temp_report.tsv > pipeline_metadata_report.tsv
  '''
}

// not to have same name collision for "results" directory sufix
process stageResults {
    input:
    file(sigfit_results_dir) from sigfit_results_dir_ch

    output:
    file("staged_result_${uuid}") into staged_sigfit_results_dir_ch

    script:
    uuid = UUID.randomUUID().toString()
    """
    mkdir staged_result_${uuid}
    cp -r $sigfit_results_dir/* staged_result_${uuid}/
    """
}

process collectResults {
    input:
    file(sigfit_results_dir) from staged_sigfit_results_dir_ch.collect()

    output:
    file("all_results") into all_sigfit_results_dir_ch

    script:
    // collect all samples present in "snv" and "sv" results to single folder, 
    // so they can be parsed by next step
    """
    echo "INFO: Check any files existance at the beginning"
    find * 
    mkdir all_results
    echo "INFO: all_results folder got created"

    numb_files_for_snv=\$(find -L -name snv | wc -l)

    # for snv folder
    if [ ! \$numb_files_for_snv == 0 ]; then
      echo "INFO: Collecting snv folders"
      mkdir all_snv
      cp -r */snv/* all_snv/
      mkdir all_results/snv
      mv all_snv/* all_results/snv/
    fi

    numb_files_for_sv=\$(find -L -name sv | wc -l)
    # for sv folder
    if [ ! \$numb_files_for_sv == 0 ]; then
      echo "INFO: Collecting sv folders"
      mkdir all_sv
      cp -r */sv/* all_sv/
      mkdir all_results/sv
      mv all_sv/* all_results/sv/
    fi

    echo "INFO: Current contents of all_results folder"
    ls -la all_results
    """
}

process signatureFitAggregate {
    label 'low_memory'
    publishDir "${params.outdir}", mode: 'copy'

    input:
    file(sigfit_results_dir) from all_sigfit_results_dir_ch
    file(signatureFitAggregate_script) from ch_signatureFitAggregate_script
    
    output:
    file "aggregate_output" into ch_aggregate_output

    script:
    """
    Rscript $signatureFitAggregate_script \
      --inputdir $sigfit_results_dir \
      --organ $params.organ \
      --outdir aggregate_output
    """
  }

process report {
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    input:
    file(report_dir) from ch_report_dir
    file(aggregate_output_dir) from ch_aggregate_output
    
    output:
    file "multiqc_report.html" into ch_multiqc_report

    script:
    """
    cp -r ${report_dir}/* .
    # convert from pdf to png
    for f in \$(ls $aggregate_output_dir/*.pdf); do
       pdftoppm \$f -png > $aggregate_output_dir/\$(echo \$(basename \$f | cut -d. -f1)).png
    done

    Rscript -e "rmarkdown::render('report.Rmd',params = list(aggregate_output_dir='$aggregate_output_dir'))"
    mv report.html multiqc_report.html
    """
}

// When the pipeline is run is not run locally
// Ensure trace report is output in the pipeline results (in 'pipeline_info' folder)

// userName = workflow.userName

// if ( userName == "ubuntu" || userName == "ec2-user") {
//   workflow.onComplete {

//   def trace_timestamp = new java.util.Date().format( 'yyyy-MM-dd_HH-mm-ss')

//   traceReport = file("/home/${userName}/nf-out/trace.txt")
//   traceReport.copyTo("results/pipeline_info/execution_trace_${trace_timestamp}.txt")
//   }
// }
