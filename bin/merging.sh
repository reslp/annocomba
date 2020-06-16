#!/bin/bash

prefix=$1

#get going
echo -e "\n$(date)\tStarting ...\n"

#combine results (this could be incorporated in the previous script)
#combine all gffs without fasta sequences
cat $(find ./ -name "$prefix.*.noseq.maker.gff" | sort) > $prefix.noseq.maker.gff
#combine all gffs and add FASTA sequences from all 
cat $prefix.noseq.maker.gff <(echo -e "##FASTA") <(for f in $(find ./ -name "$prefix.*.all.maker.gff" | sort); do cat $f | perl -ne 'chomp; if ($_ =~ /^##FASTA/){$ok=1}; if ($ok){print "$_\n"}'; done | grep -v "^##FASTA") > $prefix.all.maker.gff
#combine all proteins
cat $(find ./ -name "$prefix.*.all.maker.proteins.fasta" | sort) > $prefix.all.maker.proteins.fasta
#combine all transcripts
cat $(find ./ -name "$prefix.*.all.maker.transcripts.fasta" | sort) > $prefix.all.maker.transcripts.fasta

#extract gff by evidence
# transcript alignments
awk '{ if ($2 ~ "est2genome") print $0 }' $prefix.noseq.maker.gff > $prefix.noseq.maker.est2genome.gff
awk '{ if ($2 ~ "cdna2genome") print $0 }' $prefix.noseq.maker.gff > $prefix.noseq.maker.cdna2genome.gff
# protein alignments
awk '{ if ($2 ~ "protein2genome") print $0 }' $prefix.noseq.maker.gff > $prefix.noseq.maker.protein2genome.gff
# repeat alignments
awk '{ if ($2 ~ "repeat") print $0 }' $prefix.noseq.maker.gff > $prefix.noseq.maker.repeats.gff

#genes predicted by snap
awk '{ if ($2 ~ "snap") print $0 }' $prefix.noseq.maker.gff > $prefix.noseq.maker.snap.gff
#genes predicted by augustus
awk '{ if ($2 ~ "augustus") print $0 }' $prefix.noseq.maker.gff > $prefix.noseq.maker.augustus.gff
#genes predicted by maker
awk '{ if ($2 ~ "maker") print $0 }' $prefix.noseq.maker.gff > $prefix.noseq.maker.maker.gff

#rename genes/transcripts
#create backups
cp $prefix.all.maker.gff $refix.all.maker.backup.gff
cp $prefix.all.maker.proteins.fasta $prefix.all.maker.proteins.backup.fasta
cp $prefix.all.maker.transcripts.fasta $prefix.all.maker.transcripts.backup.fasta

maker_map_ids --prefix $prefix --justify 5 --suffix - --iterate 1 $prefix.all.maker.gff > $prefix.makerID2short.map
map_gff_ids $prefix.makerID2short.map $prefix.all.maker.gff
map_fasta_ids $prefix.makerID2short.map $prefix.all.maker.transcripts.fasta
map_fasta_ids $prefix.makerID2short.map $prefix.all.maker.proteins.fasta

echo -e "\n$(date)\tFinished!\n"
