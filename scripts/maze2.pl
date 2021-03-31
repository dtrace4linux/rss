#!/usr/bin/perl

# Taken from https://www.perlmonks.org/bare/?node_id=105074

$x=1+rand($w=pop||33);$y=1+rand($h=pop||9);sub p{print@_}@m=($t=[10
,(8)x($w+1)],(map[(2,(0)x$w,2)],1..$h),$t);sub w{$m[$y][$x]|=$_}{(@d=
($m[$y-1][$x]?():1,$m[$y+1][$x]?():2,$m[$y][$x-1]?():4,$m[$y][$x+1]?()
:8))?(@d>1?$q[@q]=[$y,$x]:1,$_=$d[rand@d],w,s/1/$y--;2/e||s/2/$y++;1/e
||s/4/$x--;8/e||s/8/$x++;4/e,w):(($y,$x)=@{shift@q||last});redo}sub r{
$m[pop][1+rand$w]|=2}r;r-2;for$y(0..$h){p$",$m[$y][$_]&8?$":'#'for@w=
0..$w;sub P{p" \n"}P;p$m[$y][$_]&2?$":'#','#'for@w;P}p$"x(2+$w*2);P
