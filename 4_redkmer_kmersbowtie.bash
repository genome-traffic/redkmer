#!/bin/bash
#PBS -N redkmer4
#PBS -l walltime=02:00:00
#PBS -l select=1:ncpus=16:mem=16gb
#PBS -e /home/nikiwind/reports
#PBS -o /home/nikiwind/reports

if [ -z ${PBS_ENVIRONMENT+x} ]
then
echo "---> running on the Perugia numbercruncher..."
source redkmer.cfg
else
echo "---> running on HPC cluster..."
source $PBS_O_WORKDIR/redkmer.cfg
module load samtools
module load bowtie/1.1.1

fi

kmers=$CWD/kmers/fasta/allkmers.fasta

printf "======= Creating bowtie index for PacBio bins =======\n"

if [ -z ${PBS_ENVIRONMENT+x} ]
	then
	$BOWTIEB $CWD/pacBio_bins/fasta/Xbin.fasta $CWD/kmers/bowtie/index/Xbin &
	$BOWTIEB $CWD/pacBio_bins/fasta/Abin.fasta $CWD/kmers/bowtie/index/Abin &
	$BOWTIEB $CWD/pacBio_bins/fasta/Ybin.fasta $CWD/kmers/bowtie/index/Ybin &
	if [ -s "$CWD/pacBio_bins/fasta/GAbin.fasta" ];then
		$BOWTIEB $CWD/pacBio_bins/fasta/GAbin.fasta $CWD/kmers/bowtie/index/GAbin & 
	fi
	wait $(jobs -p) 
else
	cp $CWD/pacBio_bins/fasta/*bin.fasta $TMPDIR/

	$BOWTIEB $TMPDIR/Xbin.fasta $TMPDIR/Xbin
	$BOWTIEB $TMPDIR/Abin.fasta $TMPDIR/Abin
	$BOWTIEB $TMPDIR/Ybin.fasta $TMPDIR/Ybin
	if [ -s "$TMPDIR/GAbin.fasta" ];then
		$BOWTIEB $TMPDIR/GAbin.fasta $TMPDIR/GAbin
	fi

	cp $TMPDIR/*ebwt $CWD/kmers/bowtie/index 2>/dev/null || :
	cp $TMPDIR/*ebwtl $CWD/kmers/bowtie/index 2>/dev/null || :

fi

if [ -z ${PBS_ENVIRONMENT+x} ]
then
	printf "======= Running bowtie against X chromosome bin =======\n"
	$BOWTIE -a -t -p $CORES -v 0 $CWD/kmers/bowtie/index/Xbin --suppress 2,3,4,5,6,7,8,9 -f $kmers  1> $CWD/kmers/bowtie/mapping/Xbin.txt 2> $CWD/kmers/bowtie/mapping/logs/Xbin_log.txt

	printf "======= Running bowtie against autosome bin =======\n"
	$BOWTIE -a -t -p $CORES -v 0 $CWD/kmers/bowtie/index/Abin --suppress 2,3,4,5,6,7,8,9 -f $kmers 1> $CWD/kmers/bowtie/mapping/Abin.txt 2> $CWD/kmers/bowtie/mapping/logs/Abin_log.txt

	printf "======= Running bowtie against Y chromosome bin =======\n"
	$BOWTIE -a -t -p $CORES -v 0 $CWD/kmers/bowtie/index/Ybin --suppress 2,3,4,5,6,7,8,9 -f $kmers 1> $CWD/kmers/bowtie/mapping/Ybin.txt 2> $CWD/kmers/bowtie/mapping/logs/Ybin_log.txt

	printf "======= Running bowtie against GA chromosome bin =======\n"
	if [ -s "$CWD/pacBio_bins/fasta/GAbin.fasta" ];then
		$BOWTIE -a -t -p $CORES -v 0 $CWD/kmers/bowtie/index/GAbin --suppress 2,3,4,5,6,7,8,9 -f $kmers 1> $CWD/kmers/bowtie/mapping/GAbin.txt 2> $CWD/kmers/bowtie/mapping/logs/GAbin_log.txt
		else
		touch $CWD/kmers/bowtie/mapping/GAbin.txt
	fi

else

	printf "======= Running bowtie against X chromosome bin =======\n"
	$BOWTIE -a -t -p $CORES -v 0 $TMPDIR/Xbin --suppress 2,3,4,5,6,7,8,9 -f $kmers  1> $TMPDIR/Xbin.txt 2> $CWD/kmers/bowtie/mapping/logs/Xbin_log.txt

	printf "======= Running bowtie against autosome bin =======\n"
	$BOWTIE -a -t -p $CORES -v 0 $TMPDIR/Abin --suppress 2,3,4,5,6,7,8,9 -f $kmers 1> $TMPDIR/Abin.txt 2> $CWD/kmers/bowtie/mapping/logs/Abin_log.txt

	printf "======= Running bowtie against Y chromosome bin =======\n"
	$BOWTIE -a -t -p $CORES -v 0 $TMPDIR/Ybin --suppress 2,3,4,5,6,7,8,9 -f $kmers 1> $TMPDIR/Ybin.txt 2> $CWD/kmers/bowtie/mapping/logs/Ybin_log.txt

	printf "======= Running bowtie against GA chromosome bin =======\n"
	if [ -s "$CWD/pacBio_bins/fasta/GAbin.fasta" ];then
		$BOWTIE -a -t -p $CORES -v 0 $TMPDIR/GAbin --suppress 2,3,4,5,6,7,8,9 -f $kmers 1> $TMPDIR/GAbin.txt 2> $CWD/kmers/bowtie/mapping/logs/GAbin_log.txt
		else
		touch $TMPDIR/GAbin.txt
	fi
fi


printf "======= extracting blast results =======\n"


if [ -z ${PBS_ENVIRONMENT+x} ]
then
	sort -k1b,1 --parallel=8 -T $CWD/temp --buffer-size=$BUFFERSIZE $CWD/kmers/bowtie/mapping/Xbin.txt | uniq -c  | awk '{print $2, $1}' >  $CWD/kmers/bowtie/mapping/kmer_hits_Xbin &
	sort -k1b,1 --parallel=8 -T $CWD/temp --buffer-size=$BUFFERSIZE $CWD/kmers/bowtie/mapping/Abin.txt | uniq -c  | awk '{print $2, $1}' >  $CWD/kmers/bowtie/mapping/kmer_hits_Abin &
	sort -k1b,1 --parallel=8 -T $CWD/temp --buffer-size=$BUFFERSIZE $CWD/kmers/bowtie/mapping/Ybin.txt | uniq -c  | awk '{print $2, $1}' >  $CWD/kmers/bowtie/mapping/kmer_hits_Ybin &
	sort -k1b,1 --parallel=8 -T $CWD/temp --buffer-size=$BUFFERSIZE $CWD/kmers/bowtie/mapping/GAbin.txt | uniq -c  | awk '{print $2, $1}' >  $CWD/kmers/bowtie/mapping/kmer_hits_GAbin &
	wait $(jobs -p)
else
	sort -k1b,1 -T $TMPDIR/temp --buffer-size=$BUFFERSIZE $TMPDIR/Xbin.txt | uniq -c  | awk '{print $2, $1}' >  $CWD/kmers/bowtie/mapping/kmer_hits_Xbin
	sort -k1b,1 -T $TMPDIR/temp --buffer-size=$BUFFERSIZE $TMPDIR/Abin.txt | uniq -c  | awk '{print $2, $1}' >  $CWD/kmers/bowtie/mapping/kmer_hits_Abin
	sort -k1b,1 -T $TMPDIR/temp --buffer-size=$BUFFERSIZE $TMPDIR/Ybin.txt | uniq -c  | awk '{print $2, $1}' >  $CWD/kmers/bowtie/mapping/kmer_hits_Ybin
	sort -k1b,1 -T $TMPDIR/temp --buffer-size=$BUFFERSIZE $TMPDIR/GAbin.txt | uniq -c  | awk '{print $2, $1}' >  $CWD/kmers/bowtie/mapping/kmer_hits_GAbin

fi


join -a1 -a2 -1 1 -2 1 -o '0,1.2,2.2' -e "0" $CWD/kmers/bowtie/mapping/kmer_hits_Xbin $CWD/kmers/bowtie/mapping/kmer_hits_Abin > $CWD/kmers/bowtie/mapping/kmer_hits_XAbin
join -a1 -a2 -1 1 -2 1 -o '0,1.2,1.3,2.2' -e "0" $CWD/kmers/bowtie/mapping/kmer_hits_XAbin $CWD/kmers/bowtie/mapping/kmer_hits_Ybin > $CWD/kmers/bowtie/mapping/kmer_hits_XAYbin
join -a1 -a2 -1 1 -2 1 -o '0,1.2,1.3,1.4,2.2' -e "0" $CWD/kmers/bowtie/mapping/kmer_hits_XAYbin $CWD/kmers/bowtie/mapping/kmer_hits_GAbin > $CWD/kmers/bowtie/mapping/kmer_hits_bins

rm $CWD/kmers/bowtie/mapping/kmer_hits_XAbin
rm $CWD/kmers/bowtie/mapping/kmer_hits_XAYbin

awk '{print $0, ($2+$3+$4+$5)}' $CWD/kmers/bowtie/mapping/kmer_hits_bins > tmpfile; mv tmpfile $CWD/kmers/bowtie/mapping/kmer_hits_bins
awk '{print $0, ($2/$6)}' $CWD/kmers/bowtie/mapping/kmer_hits_bins > tmpfile; mv tmpfile $CWD/kmers/bowtie/mapping/kmer_hits_bins


printf "======= merging bowtie bin results to kmer_counts data =======\n"

if [ -z ${PBS_ENVIRONMENT+x} ]
then
	sort -k1b,1 --parallel=8 -T $CWD/temp --buffer-size=$BUFFERSIZE $CWD/kmers/bowtie/mapping/kmer_hits_bins > tmpfile1; mv tmpfile1 $CWD/kmers/bowtie/mapping/kmer_hits_bins & 
	sort -k1b,1 --parallel=8 -T $CWD/temp --buffer-size=$BUFFERSIZE $CWD/kmers/rawdata/kmers_to_merge > tmpfile2; mv tmpfile2 $CWD/kmers/rawdata/kmers_to_merge &
	wait $(jobs -p)
else
	sort -k1b,1 -T $TMPDIR/temp --buffer-size=$BUFFERSIZE $CWD/kmers/bowtie/mapping/kmer_hits_bins > tmpfile1; mv tmpfile1 $CWD/kmers/bowtie/mapping/kmer_hits_bins
	sort -k1b,1 -T $TMPDIR/temp --buffer-size=$BUFFERSIZE $CWD/kmers/rawdata/kmers_to_merge > tmpfile2; mv tmpfile2 $CWD/kmers/rawdata/kmers_to_merge
fi

join -a1 -a2 -1 1 -2 1 -o '0,2.2,2.3,2.4,2.5,2.6,1.2,1.3,1.4,1.5,1.6,1.7' -e "0"  $CWD/kmers/bowtie/mapping/kmer_hits_bins $CWD/kmers/rawdata/kmers_to_merge > $CWD/kmers/rawdata/kmers_hits_results
awk '{print $0, "0"}'  $CWD/kmers/rawdata/kmers_hits_results > tmpfile; mv tmpfile $CWD/kmers/rawdata/kmers_hits_results 
awk -v xsi="$XSI" '{if ($12>=xsi) {$13="pass"}; print}' $CWD/kmers/rawdata/kmers_hits_results > tmpfile; mv tmpfile $CWD/kmers/rawdata/kmers_hits_results
awk -v xsi="$XSI" '{if ($12<xsi) {$13="fail"}; print}' $CWD/kmers/rawdata/kmers_hits_results > tmpfile; mv tmpfile $CWD/kmers/rawdata/kmers_hits_results
awk '{if ($11==0) {$13="nohits"}; print}' $CWD/kmers/rawdata/kmers_hits_results > tmpfile; mv tmpfile $CWD/kmers/rawdata/kmers_hits_results



printf "======= generating Xkmers.fasta file for off-target analysis =======\n"

awk '{if ($13=="pass") print $1, $2}' $CWD/kmers/rawdata/kmers_hits_results |awk '{print ">"$1"\n"$2}' > $CWD/kmers/fasta/Xkmers.fasta

printf "======= generating kmers_all_results file =======\n"

awk -v OFS="\t" '$1=$1' $CWD/kmers/rawdata/kmers_hits_results > tmpfile; mv tmpfile $CWD/kmers/rawdata/kmers_hits_results

#Add column header
awk 'BEGIN {print "kmer_id\tseq\tfemale\tmale\tCQ\tsum\thits_X\thits_A\thits_Y\thits_GA\thits_sum\tperchitsX\thits_threshold"} {print}' $CWD/kmers/rawdata/kmers_hits_results > tmpfile; mv tmpfile $CWD/kmers/rawdata/kmers_hits_results

printf "======= done step 4 =======\n"

