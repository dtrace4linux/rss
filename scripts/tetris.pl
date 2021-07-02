#!/usr/bin/perl

# https://www.colinfahey.com/tetris/tetris.html
# http://www.seanadams.com/perltris

$_='A=15; B=30; 
select(stdin); 
$|=1; 
select(stdout);
$|=1; 

system "stty -echo -icanon eol \001"; 

for C(split(/\s/,"010.010.010.010
77.77 022.020.020 330.030.030 440.044.000 055.550.000 666.060.".
"000")){D=0;for E(split(/\./,C)){F=0;for G(split("",E)){C[P][F++
][D]=G} D++}J[P]=F; I[P++] =D}%L=split(/ /,"m _".chr(72)." c 2".
chr(74)." a _m");

sub a{
for K(split(/ /,shift)){(K,L)=split(/=/,K
);K=L{K};K=~s/_/L/; printf "%c[K",27}
}

sub u{a("a=40");for D(0..B
-1){for F(0..A-1){M=G[F][D];if(R[F][D]!=M) {R[F][D]=M;a("m"."=".
(5+D).";".(F*2+5)); a("a=".(40+M).";" .(30+M));print " "x2}}}a(
"m=0;0 a=37;40")
}

sub r{(N)=@_;while(N--) {Q=W;W=O=H;H=Q;for F( 0
..Q-1){for D(0..O-1) {Q[F][D]=K[F][D]}}for F(0..O-1){for D(0..Q-
1){K[F][D]= Q[Q-D-1][F]}}}
}

sub l{for F(0..W-1){for D(0..H-1){(K[
F][D]&& ((G[X+F][Y+D])|| (X+F<0)||(X+F>=A)|| (Y+D>=B)))&& return
0}}1
}

sub p {
for F(0..W-1){for D(0..H-1){(K[F][D]>0)&&(G[X+F][Y+D] =K[F][D]) }}1
}

sub o{for F(0..W-1){for D(0..H-1){(K[F][D]>0)&&(G[
X+F][ Y+D]=0)}}}

sub n
{
	C=int(rand(P)) ;
	W=J[C];H=I[C];X=int(A/2)-1;
	Y=0;
	for F(0..W-1) {
		for D(0..H-1){
			K[F][D]= C[C][F][D]
		}
	}
	r(int(rand (4)));l&&p
}

sub c
{
d:
	for(D=B;D>=0;D--) {
		for F(0..A-1){
			G[F][D]||next d
		}
	for(D2=D;D2>=0; D2--){
	for F(0..A-1){G[F][D2]= (D2>1)?G[F][D2-1 ]:0; }}u;}
}

	a ("m=0;0 a=0;37;40 c");

	print "\n\n".4x" "." "x(A-4).
		"perltris\n".(" "x4)."--"xA."\n".((" "x3)."|"." "x(A*2)."|\n")xB
	.(" "x4). "--"xA."\n";
	n;

for(;;) {
	u;
	R=chr(1); 
	(S,T)=select(R,U,V, 0.01);
	if(S) {
		Z=getc;
	} else {
		if($e++>20){
			Z=" ";

			# Auto move
			my @moves = ("k", "j", "l", " ");
			Z = $moves[int(rand(scalar(@moves)))];

			#print "Z=$Z.\n";
			$e=0;
		} else{
			next;
		} 
	}


	if(Z eq "k"){o;r(1);l||r(3);p}; 
	if(Z eq "j"){o;X--;l||X++;p}; 
	if (Z eq "l"){o;X++;l||X--;p};
	# ensure we keep dropping
	if(Z eq " " || 1) {
	o;Y++;(E=l)||Y--;p;E|| c
	|c|c|c|c|n||
	goto g;};

	if(Z eq "q"){
		last;
	}
}

g: a("a=0 m=".(B+8).";0" ); 

system "stty sane"; '; s/([A-Z])/\$$1/g; s/\%\$/\%/g; eval;
