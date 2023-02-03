{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit OpenScada;

{$warn 5023 off : no warning about unused units}
interface

uses
  OSSerial, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('OSSerial', @OSSerial.Register);
end;

initialization
  RegisterPackage('OpenScada', @Register);
end.
