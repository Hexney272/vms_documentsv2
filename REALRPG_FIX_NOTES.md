# RealRPG javított vms_documentsv2 csomag

## Mit javítottam

- Olvashatóbb, tagoltabb szerver- és kliensoldali logika.
- Szerveroldali védelem a kliensről hamisítható dokumentumkiadás ellen.
- A dokumentum megosztása most ellenőrzi, hogy a játékos tényleg érvényes, saját dokumentumot mutat-e.
- ESX pénzkezelés javítva: cash esetén `getMoney/removeMoney`, nem hibára hajlamos account lekérés.
- `player_documents` tábla automatikus létrehozása és hiányzó oszlopok pótlása.
- SSN modul mysql-async kompatibilisre javítva; nem keveri az oxmysql await/prepare hívásokat.
- Adatbázis várakozások timeoutot kaptak, hogy egy hibás query ne akassza meg örökre a scriptet.
- MugShotBase64 export ellenőrizve van használat előtt; hiba esetén nem omlik össze a kliens.
- A sorozatszám-ellenőrzés szerveroldalon is jobhoz kötött, nem csak kliensoldali menüből.
- NUI oldalon alap HTML escape bekerült a dinamikus dokumentumadatokhoz.
- Modell/ped/prop betöltés biztonságosabb lett invalid model vagy timeout esetén.

## Fontos

- A resource neve maradhat `vms_documentsv2`.
- Kell hozzá a `MugShotBase64` resource, ha fotós dokumentumot használsz.
- Ha ox_inventory-t használsz, a dokumentum metadata megmarad. Alap ESX inventory metadata nélkül nem alkalmas teljes dokumentumadat tárolásra.
- Éles szerveren csere előtt készíts mentést a régi resource-ról és az adatbázisról.
