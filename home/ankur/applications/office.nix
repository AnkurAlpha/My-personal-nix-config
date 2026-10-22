{ lib, pkgs, osConfig, ... }:
let
  c = osConfig.my.apps.office;
  # Coexist with any earlier Productivity module. Avoid installing its
  # duplicate packages when that category and matching switch are enabled.
  productivity = lib.attrByPath [ "my" "apps" "productivity" ] { } osConfig;
  inProductivity = name:
    (productivity.enable or false) &&
    (lib.attrByPath [ name "enable" ] false productivity);
  selected = name: c.enable && c.${name}.enable;
  use = name: pkg: lib.optional (selected name && !inProductivity name) pkg;
  plain = name: pkg: lib.optional (selected name) pkg;
in
{
  # No changes to KDE Plasma/KWallet, file associations, GTK/Qt, or system services.
  home.packages =
       use "libreoffice" pkgs.libreoffice-qt
    ++ use "onlyoffice" pkgs.onlyoffice-desktopeditors
    ++ plain "freeoffice" pkgs.freeoffice
    ++ use "okular" pkgs.kdePackages.okular
    ++ use "pdfarranger" pkgs.pdfarranger
    ++ use "xournalpp" pkgs.xournalpp
    ++ plain "poppler" pkgs.poppler-utils
    ++ plain "hunspell" pkgs.hunspell
    ++ plain "hunspell" pkgs.hunspellDicts.en_US
    ++ plain "zathura" pkgs.zathura
    ++ plain "papers" pkgs.papers
    ++ plain "qpdf" pkgs.qpdf
    ++ plain "pandoc" pkgs.pandoc
    ++ plain "tesseract" pkgs.tesseract
    ++ use "foliate" pkgs.foliate;
}
