#! /usr/bin/perl

# Taken from https://www.perlmonks.org/bare/?node_id=105074

$|=@j='@@@@@@@@@@@@@@@@@@@@@@@@@@'=~/./gs;

sub p
{print@_}

p$H="\e[H",
"\e[J",map@$_,@m=map[//g],<>;@y=$"='';$_="@{$m[1]}";/\S+/g;p"$H ",' '
x($x[0]=pos);$_=C;{$o=0;$y=$y[-1];$x=$x[-1];s|A|$m[$y][++$x]=~/ /?$o=C
:D|e||s|C|$m[++$y][$x]=~/ /?$o=B:A|e||s|B|$m[$y][--$x]=~/ /?$o=D:C|e||
s|D|$m[--$y][$x]=~/ /?$o=A:B|e;$o||redo;$y^$y[-2]||$x^$x[-2]?($y[@y]=$
y,$x[@x]=$x):(--$#y,$#x--,$j-=2,p"\e[D ");
$y&&$x&&$y<$#m&$x<$#{$m[0]}
&&do{p"\e[$_\e[43m\e[D$j[$j++]";$j%=@j;

select$,,$,,$,,.06;redo}}

p$H,$/x@m
