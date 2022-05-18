# mutational-signature-aggregation-nf

<!-- This README.md is the single page user documentation for this pipeline. -->

This is a nexflow pipeline which aggregates the results from [mutational-signature-nf](https://github.com/lifebit-ai/mutational-signature-nf) pipeline and produce combined table and plots.

## Pipeline description

## Input

There are two primary input paramrters - 

### Parameters

| param | default | description | 
|---|---|---|
| sigfit_results_dir | null | The results output directory from [mutational-signature-nf] pipeline |
| organ | "Breast" | Which organ was used while running [mutational-signature-nf] pipeline |

## Output

Output generates a table (TSV file) and plot with combined results of all the samples from [mutational-signature-nf] pipeline run. Also present them in a HTML report format.

## Usage

```bash
nextflow run main.nf \
    --sigfit_results_dir "s3://lifebit-featured-datasets/pipelines/mutational-signature-nf/example-output/sigfit_results_out/" \
    --organ "Breast"
```

[mutational-signature-nf]: https://github.com/lifebit-ai/mutational-signature-nf

<!-- For Sphinx doc, This option will be auto rendered help() section from Nextflow main.nf in the doc build -->


<!------------------
Build of this doc in github handle by - .github/workflows/build-deploy-doc.yml

To build this doc locally follow these steps.

Needs to have installed - 
1. sphinx
2. sphinx-rtd-theme
3. nextflow

Supposing your currently in base directory of the pipeline -
```
cd docs && bash src/pre-build.sh
cp README.md src
cd src && make html 
```
index.html will be generated in `docs/src/build/html` folder
-->