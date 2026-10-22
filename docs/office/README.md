# Office & Documents module

Integrated with the existing `my.apps` switches and Home Manager.

## Configuration

Edit `hosts/ankur-laptop/applications.nix` under `my.apps.office`.
Set `office.enable = false;` to disable all packages in this module.
Each `office.<tool>.enable` can be toggled independently.

Defaults: LibreOffice (Qt), Okular, PDF Arranger, Xournal++, Poppler tools,
and Hunspell with an English dictionary are enabled. Other programs are off.

## Optional packages

- ONLYOFFICE: `onlyoffice.enable = true;`
- SoftMaker FreeOffice: `freeoffice.enable = true;` (unfree package;
  requires Nixpkgs unfree permission; may require accepting upstream terms)
- Zathura, Papers, QPDF, Pandoc, Tesseract, Foliate: toggle as needed.

The package names come from your pinned Nixpkgs; an unavailable or broken
optional package will be reported when you enable it and build.

If the earlier `my.apps.productivity` category is also enabled, overlapping
packages (LibreOffice, ONLYOFFICE, Okular, PDF Arranger, Xournal++, Foliate)
are delegated to Productivity where its corresponding switch is enabled.
Use one category as the source of truth for those applications.

## Verification

    nh os build ~/nixos-config -H ankur-laptop
    nh os switch ~/nixos-config -H ankur-laptop
    command -v libreoffice okular pdfarranger xournalpp pdftotext

No change to default PDF/file associations is made, and nothing from
`/mnt/garuda` is modified or copied.
