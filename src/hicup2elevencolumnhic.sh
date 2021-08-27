#!/bin/bash
samtools view $1 | awk 'BEGIN {FS="\t"; OFS="\t"} {name1=$1; str1=and($2,16); chr1=substr($3, 4); pos1=$4; mapq1=$5; getline; name2=$1; str2=and($2,16); chr2=substr($3, 4); pos2=$4; mapq2=$5; if(name1==name2) { if (chr1>chr2){print name1, str2, chr2, pos2,1, str1, chr1, pos1, 0, mapq2, mapq1} else {print name1, str1, chr1, pos1, 0, str2, chr2, pos2 ,1, mapq1, mapq2}}}'  | sort -k3,3d -k7,7d > $2 


