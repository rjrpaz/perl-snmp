#!/usr/bin/perl

use strict;
use SNMP_util;
use Term::ReadLine;

my $debug = 0;
my @interfaces = ();

if ($#ARGV != 1)
{
	print <<EOF;

Forma de Uso:

	$0 <host> <community_name>

Ejemplo:
	$0 192.168.17.254 public

EOF
	exit 0;
}

my $host = $ARGV[0];
my $community = $ARGV[1];

my $oid = "ifType";

my %oper_status = ();
my %admin_status = ();
my %descr = ();

(my @respuestas) = snmpwalk("$community\@$host", $oid);

foreach my $respuesta (@respuestas)
{
	my ($interface, $tipo) = split /\:/, $respuesta;
	if ($tipo eq "6")
	{
		print "Interfaz $interface \n" if $debug;
		push (@interfaces, $interface);
	}
}

&listar_estado();

my $term = new Term::ReadLine 'Interfaz a cambiar de estado';

my $prompt = ": ";
my $OUT = $term->OUT || \*STDOUT;

while (defined (my $victima = $term->readline($prompt)))
{
	exit if ($victima eq 'q');

	my $hay_coincidencia = 0;
	foreach my $interface (@interfaces)
	{
		if ($interface eq $victima)
		{
			$hay_coincidencia = 1;
			last;
		}
	}

	my $valor;
	my $oid = "ifAdminStatus.".$victima;
	if ($hay_coincidencia == 0)
	{
		print "No existe tal interfaz\n";
	}
	else
	{
		if ($admin_status{$victima} eq 'up')
		{
			$valor = 2;
		}
		elsif ($admin_status{$victima} eq 'down')
		{
			$valor = 1;
		}
		else
		{
			print "La interfaz no esta en un estado intercambiable\n";
			next;
		}
		(my $respuesta) = snmpset("$community\@$host", $oid, 'integer', $valor);
		&listar_estado();
	}
}



sub listar_estado
{

	foreach my $interface (@interfaces)
	{
		my $oid = "ifAdminStatus.".$interface;
		(my $respuesta) = snmpget("$community\@$host", $oid);
		(my $desc) = snmpget("$community\@$host", "ifDescr.".$interface);
		$descr{$interface} = $desc;
	
		if ($respuesta)
		{
			if ($respuesta eq "1")
			{
				$respuesta = "up";
			}
			elsif ($respuesta eq "2")
			{
				$respuesta = "down";
			}
			else
			{
				$respuesta = "?";
			}
	
			print "Interface $interface Estado Administrativo $respuesta \n" if $debug;
			$admin_status{$interface} = $respuesta;
		}
		else
		{
			die "Problemas con consulta de $oid a $host";
		}
	
		$oid = "ifOperStatus.".$interface;
		($respuesta) = snmpget("$community\@$host", $oid);
	
		if ($respuesta)
		{
			if ($respuesta eq "1")
			{
				$respuesta = "up";
			}
			elsif ($respuesta eq "2")
			{
				$respuesta = "down";
			}
			else
			{
				$respuesta = "?";
			}

			print "Interface $interface Estado Operativo $respuesta \n" if $debug;
			$oper_status{$interface} = $respuesta;
		}
		else
		{
			die "Problemas con consulta de $oid a $host";
		}
	}

	print "\nIndique la interfaz que quiera cambiar de estado\n";
	print "(o salga con la letra 'q')\n\n";
	print "Interfaz\tAdminStatus\tOperStatus\n\n";

	foreach my $interface (@interfaces)
	{
		print $interface,"(".$descr{$interface}.")\t\t",$admin_status{$interface},"\t\t",$oper_status{$interface},"\n";
	}
}


exit 0;


