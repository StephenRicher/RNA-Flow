#!/bin/sh

#
# Downloads sequence for the BDGP6 release 84 version of drosophila melanogaster (fly) from
# Ensembl.
#
# Note that Ensembl's build has three categories of compressed fasta
# files:
#
# The base files, named ??.fa.gz
#
# By default, this script builds and index for just the base files,
# since alignments to those sequences are the most useful.  To change
# which categories are built by this script, edit the CHRS_TO_INDEX
# variable below.
#


ENSEMBL_RELEASE=84
ENSEMBL_BASE=ftp://ftp.ensembl.org/pub/release-${ENSEMBL_RELEASE}/fasta/drosophila_melanogaster/dna
ENSEMBL_GTF_BASE=ftp://ftp.ensembl.org/pub/release-${ENSEMBL_RELEASE}/gtf/drosophila_melanogaster
GTF_FILE=Drosophila_melanogaster.BDGP6.${ENSEMBL_RELEASE}.gtf

get() {
	file=$1
	if ! wget --version >/dev/null 2>/dev/null ; then
		if ! curl --version >/dev/null 2>/dev/null ; then
			echo "Please install wget or curl somewhere in your PATH"
		fi
		curl -o `basename $1` $1
		return $?
	else
		wget $1
		return $?
	fi
}

HISAT2_BUILD_EXE=./hisat2-build
if [ ! -x "$HISAT2_BUILD_EXE" ] ; then
	if ! which hisat2-build ; then
		echo "Could not find hisat2-build in current directory or in PATH"
		exit 1
	else
		HISAT2_BUILD_EXE=`which hisat2-build`
	fi
fi

HISAT2_SS_SCRIPT=./hisat2_extract_splice_sites.py
if [ ! -x "$HISAT2_SS_SCRIPT" ] ; then
	if ! which hisat2_extract_splice_sites.py ; then
		echo "Could not find hisat2_extract_splice_sites.py in current directory or in PATH"
		exit 1
	else
		HISAT2_SS_SCRIPT=`which hisat2_extract_splice_sites.py`
	fi
fi

HISAT2_EXON_SCRIPT=./hisat2_extract_exons.py
if [ ! -x "$HISAT2_EXON_SCRIPT" ] ; then
	if ! which hisat2_extract_exons.py ; then
		echo "Could not find hisat2_extract_exons.py in current directory or in PATH"
		exit 1
	else
		HISAT2_EXON_SCRIPT=`which hisat2_extract_exons.py`
	fi
fi

rm -f genome.fa
F=Drosophila_melanogaster.BDGP6.dna.toplevel.fa
if [ ! -f $F ] ; then
	get ${ENSEMBL_BASE}/$F.gz || (echo "Error getting $F" && exit 1)
	gunzip $F.gz || (echo "Error unzipping $F" && exit 1)
        samtools faidx $F
        samtools faidx $F 3L >  genome.fa
fi

if [ ! -f $GTF_FILE ] ; then
       get ${ENSEMBL_GTF_BASE}/${GTF_FILE}.gz || (echo "Error getting ${GTF_FILE}" && exit 1)
       gunzip ${GTF_FILE}.gz || (echo "Error unzipping ${GTF_FILE}" && exit 1)
       grep '^3L' ${GTF_FILE} > tmp
       mv tmp ${GTF_FILE}
       ${HISAT2_SS_SCRIPT} ${GTF_FILE} > genome.ss
       ${HISAT2_EXON_SCRIPT} ${GTF_FILE} > genome.exon
fi

CMD="${HISAT2_BUILD_EXE} -p 4 genome.fa --ss genome.ss --exon genome.exon genome_tran"
echo Running $CMD
if $CMD ; then
	echo "genome index built; you may remove fasta files"
else
	echo "Index building failed; see error message"
fi
