# This existing laptop's identity. New hosts/ISOs choose their own account.
{ ... }: {
  my.user = {
    name = "ankur";
    description = "Ankur Kumar";
    git.name = "AnkurAlpha";
    git.email = "comp2ankur@gmail.com";
  };
}
