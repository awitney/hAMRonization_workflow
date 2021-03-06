rule get_kmerresistance_db:
    input:
       resfinder_db = os.path.join(config["params"]["db_dir"], "resfinder_db")
    output:
       kma_resfinder_db_name = os.path.join(config["params"]["db_dir"], "kmerresistance", 'resfinder_kma.name'),
       species_db_name = os.path.join(config["params"]["db_dir"], "kmerresistance", 'bacteria.name')
    params:
        db_dir = os.path.join(config["params"]["db_dir"], 'kmerresistance'),
        kma_resfinder_db = os.path.join(config["params"]["db_dir"], "kmerresistance", 'resfinder_kma'),
        species_db = os.path.join(config["params"]["db_dir"], "kmerresistance", 'bacteria')
    log:
       "logs/kmerresistance_db.log"
    conda:
      "../envs/kmerresistance.yaml"
    shell:
        """
        # proper database is downloaded like this but is 20G and downloads
        # from the DTU FTP very slowly, so not going to support this feature
        # for now and just use a single type klebsiella genome for now
        #pushd {params.db_dir}
        #git clone https://bitbucket.org/genomicepidemiology/kmerfinder_db.git
        #cd kmerfinder_db
        #export KmerFinder_DB=$(pwd)
        #bash INSTALL.sh $KmerFinder_DB bacteria latest
        curl https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/240/185/GCF_000240185.1_ASM24018v2/GCF_000240185.1_ASM24018v2_genomic.fna.gz | gunzip > {params.db_dir}/klebsiella_type_genome.fasta 
        kma index -i {params.db_dir}/klebsiella_type_genome.fasta -o {params.species_db}

        cat {input.resfinder_db}/*.fsa > {params.db_dir}/resfinder.fsa
        kma index -i {params.db_dir}/resfinder.fsa -o {params.kma_resfinder_db}
        """
     
rule run_kmerresistance:
    input:
        read1 = lambda wildcards: _get_seq(wildcards, 'read1'),
        read2 = lambda wildcards: _get_seq(wildcards, 'read2'),
        kma_resfinder_db_name = os.path.join(config["params"]["db_dir"], "kmerresistance", 'resfinder_kma.name'),
        species_db_name = os.path.join(config["params"]["db_dir"], "kmerresistance", 'bacteria.name')
    output:
        report = "results/{sample}/kmerresistance/results.KmerRes",
        metadata = "results/{sample}/kmerresistance/metadata.txt"
    message: "Running rule run_kmerresistance on {wildcards.sample} with reads"
    log:
       "logs/kmerresistance_{sample}.log"
    conda:
      "../envs/kmerresistance.yaml"
    threads:
       config["params"]["threads"]
    params:
        output_folder = "results/{sample}/kmerresistance/",
        kma_resfinder_db = os.path.join(config["params"]["db_dir"], "kmerresistance", 'resfinder_kma'),
        species_db = os.path.join(config["params"]["db_dir"], "kmerresistance", 'bacteria')
    shell:
       """
       zcat {input.read1} {input.read2} > {params.output_folder}/temp_all_reads.fq
       kmerresistance -i {params.output_folder}/temp_all_reads.fq -t_db {params.kma_resfinder_db} -s_db {params.species_db} -o {params.output_folder}/results > {log} 2>&1
       rm {params.output_folder}/temp_all_reads.fq
       kmerresistance -v 2>&1 | perl -p -e 's/KmerResistance-(.+)/analysis_software_version: $1/' > {output.metadata}
       """
