# Hardware-specific detected bus IDs. Switch: my.hardware.gpu.enable.
{ ... }: {
  imports = [ ../../modules/hardware/nvidia-hybrid.nix ];
  my.hardware.gpu = {
    enable = true;
    integratedVendor = "amd";
    integratedBusId = "PCI:5@0:0:0";
    nvidiaBusId = "PCI:1@0:0:0";
  };
}
