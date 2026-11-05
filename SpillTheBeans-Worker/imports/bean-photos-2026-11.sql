-- Photos for beans that were in the app before the import queue (matched on exact product names).
-- Each image_key points at an img:<key> entry in the COFFEE_IMAGES KV namespace. Only fills beans without a photo.
-- Manhattan Coffee Roasters: Acacia Hills (https://manhattancoffeeroasters.com/product/coffees/4competition/acacia-hills/)
UPDATE coffees SET image_key = '8b4e31a16a994d1216c2941f2a90d358' WHERE id = 'C0FFEE03-0005-4000-8000-000000000005' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Bombe (https://manhattancoffeeroasters.com/product/coffees/3exceptional/bombe/)
UPDATE coffees SET image_key = 'ab9eb00e0f47de47a88b60a47fb8a7f6' WHERE id = 'C0FFEE03-0010-4000-8000-000000000010' AND image_key IS NULL;
-- Manhattan Coffee Roasters: El Ingenio-Meraki (https://manhattancoffeeroasters.com/product/meraki/el-ingenio-meraki/)
UPDATE coffees SET image_key = '9886be64bd42d3ef376d71b2378e6bd0' WHERE id = 'C0FFEE03-0001-4000-8000-000000000001' AND image_key IS NULL;
-- Manhattan Coffee Roasters: El Paseo (https://manhattancoffeeroasters.com/product/coffees/3exceptional/el-paseo/)
UPDATE coffees SET image_key = '49cc753df3ec3f0ffa9162914698730c' WHERE id = 'C0FFEE06-0001-4000-8000-000000000001' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Jose Jijón (https://manhattancoffeeroasters.com/product/coffees/5world-class/jose-jijon-putushio/)
UPDATE coffees SET image_key = '505cc954c75e20f3e78513317ecd1f95' WHERE id = 'C0FFEE03-0012-4000-8000-000000000012' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Karimikui (https://manhattancoffeeroasters.com/product/coffees/2rare/karimikui/)
UPDATE coffees SET image_key = 'b7056c8702565b1c3857d00503d1bdaf' WHERE id = 'C0FFEE06-0002-4000-8000-000000000002' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Las Marias (https://manhattancoffeeroasters.com/product/coffees/4competition/las-marias/)
UPDATE coffees SET image_key = 'a111f7a2336d0b2a116e7d6090449b64' WHERE id = 'C0FFEE06-0004-4000-8000-000000000004' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Pepe Jijón (https://manhattancoffeeroasters.com/product/coffees/5world-class/pepe-jijon-sidra/)
UPDATE coffees SET image_key = '135795b3182c70389a6b0292fdd6cd96' WHERE id = 'C0FFEE03-0003-4000-8000-000000000003' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Rio Dulce (https://manhattancoffeeroasters.com/product/coffees/5world-class/rio-dulce/)
UPDATE coffees SET image_key = '8dad3403563dd5cc79db7b91838067e3' WHERE id = 'C0FFEE06-0005-4000-8000-000000000005' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Rosa Dominguez (https://manhattancoffeeroasters.com/product/coffees/5world-class/rosa-dominguez/)
UPDATE coffees SET image_key = '1584635ea819f214d32d17c3e83c778a' WHERE id = 'C0FFEE03-0007-4000-8000-000000000007' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Shyira (https://manhattancoffeeroasters.com/product/coffees/2rare/shyira/)
UPDATE coffees SET image_key = '38b6f6100d03b17ea206505f06f5f973' WHERE id = 'C0FFEE03-0004-4000-8000-000000000004' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Yilver Pajoy (https://manhattancoffeeroasters.com/product/coffees/4competition/yilver-pajoy/)
UPDATE coffees SET image_key = 'c4cc89b6ca23641814a01627f64bc417' WHERE id = 'C0FFEE06-0003-4000-8000-000000000003' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Kalila Kantengwa (https://manhattancoffeeroasters.com/product/meraki/kalila-kantengwa-meraki/)
UPDATE coffees SET image_key = '3e1c06b2c1475d1fa671b2da3aa817f3' WHERE id = 'C0FFEE03-0008-4000-8000-000000000008' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Sweet Valley (https://manhattancoffeeroasters.com/product/meraki/sweet-valley-meraki/)
UPDATE coffees SET image_key = '73923a0e3b10a6e777a7e3aa4d59d15f' WHERE id = 'C0FFEE03-0011-4000-8000-000000000011' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Finca Soledad (https://manhattancoffeeroasters.com/product/coffees/5world-class/la-soledad/)
UPDATE coffees SET image_key = '469afbbd4c862d83ad1b11bd5a79c35c' WHERE id = 'C0FFEE03-0002-4000-8000-000000000002' AND image_key IS NULL;
-- Manhattan Coffee Roasters: El Ingenio (https://koffiekenner.com/en/products/el-ingenio)
UPDATE coffees SET image_key = '1be6f46586dd22ca700df6ecf460d8e2' WHERE id = 'C0FFEE03-0006-4000-8000-000000000006' AND image_key IS NULL;
-- Manhattan Coffee Roasters: Shoondhisa Anaerobic (https://koffiekenner.com/en/products/nieuw-city-limits-2)
UPDATE coffees SET image_key = '20ba4a04266c7b13f256fc8d7d7960d2' WHERE id = 'C0FFEE06-0007-4000-8000-000000000007' AND image_key IS NULL;
-- Schot Coffee Roasters: Brazil Dulce (https://schotcoffeeroasters.nl/webwinkel/coffee/brazilie/brazilie-dulce/)
UPDATE coffees SET image_key = 'e321972574204c3d66fdaaf48bce5ed3' WHERE id = 'C0FFEE05-0017-4000-8000-000000000017' AND image_key IS NULL;
-- Schot Coffee Roasters: Colombia Casa (https://schotcoffeeroasters.nl/webwinkel/coffee/colombia/colombia-casa/)
UPDATE coffees SET image_key = '3918d21b57efa527de481b8fed1e68d0' WHERE id = 'C0FFEE05-0009-4000-8000-000000000009' AND image_key IS NULL;
-- Schot Coffee Roasters: Colombia Jesús Cerón (https://schotcoffeeroasters.nl/webwinkel/coffee/colombia/colombia-jesus-ceron/)
UPDATE coffees SET image_key = '5110a1a58b938badc83ffbff9011c211' WHERE id = 'C0FFEE05-0010-4000-8000-000000000010' AND image_key IS NULL;
-- Schot Coffee Roasters: Colombia La Macarena Decaf (https://schotcoffeeroasters.nl/webwinkel/coffee/colombia/colombia-wilton-bentez-decaf/)
UPDATE coffees SET image_key = 'fbabffd7fadc5507d6ab30d47e62effc' WHERE id = 'C0FFEE05-0004-4000-8000-000000000004' AND image_key IS NULL;
-- Schot Coffee Roasters: Colombia Marcel Ordonez Pink Bourbon (https://schotcoffeeroasters.nl/webwinkel/coffee/colombia/colombia-marcel-ordonez/)
UPDATE coffees SET image_key = '31f776b65100c2b93615b76a6dd7837e' WHERE id = 'C0FFEE05-0012-4000-8000-000000000012' AND image_key IS NULL;
-- Schot Coffee Roasters: Ecuador El Dorado Wush Wush Natural (https://schotcoffeeroasters.nl/webwinkel/coffee/ecuador/ecuador-el-dorado-wush-wush-natural/)
UPDATE coffees SET image_key = 'b282274eb4a5252ec905a571b919be1d' WHERE id = 'C0FFEE05-0002-4000-8000-000000000002' AND image_key IS NULL;
-- Schot Coffee Roasters: Ethiopia Kebena Natural Decaf (https://schotcoffeeroasters.nl/webwinkel/coffee/ethiopie/ethiopia-kebena-natural-decaf/)
UPDATE coffees SET image_key = '340b02a8c9caf3b529d48f9ffe444b72' WHERE id = 'C0FFEE05-0014-4000-8000-000000000014' AND image_key IS NULL;
-- Schot Coffee Roasters: Ethiopia Mensur Abahika Decaf (https://schotcoffeeroasters.nl/webwinkel/coffee/ethiopie/ethiopia-mensur-abahika-decaf/)
UPDATE coffees SET image_key = '16fd14b2cf1cf68711c16aef61f2ddc3' WHERE id = 'C0FFEE05-0015-4000-8000-000000000015' AND image_key IS NULL;
-- Schot Coffee Roasters: Peru Blanca Padilla Geisha (https://schotcoffeeroasters.nl/webwinkel/coffee/peru/peru-blanca-campos/)
UPDATE coffees SET image_key = 'f2b6dafd53a9666626c50447a34e75f2' WHERE id = 'C0FFEE05-0005-4000-8000-000000000005' AND image_key IS NULL;
-- Schot Coffee Roasters: Peru Carnaval (https://schotcoffeeroasters.nl/webwinkel/coffee/espresso/peru-carnaval/)
UPDATE coffees SET image_key = 'a013637b7304ce7901c9e205a6278963' WHERE id = 'C0FFEE05-0011-4000-8000-000000000011' AND image_key IS NULL;
-- Schot Coffee Roasters: Peru Hugo Pareja SL9 (https://schotcoffeeroasters.nl/webwinkel/coffee/thailand/peru-hugo-pareja/)
UPDATE coffees SET image_key = '0a3318dd0c779757980901f40b798ae4' WHERE id = 'C0FFEE05-0008-4000-8000-000000000008' AND image_key IS NULL;
-- Schot Coffee Roasters: Tanzania Acacia Hills Kent (https://schotcoffeeroasters.nl/webwinkel/coffee/tanzania-acacia-hills-kent/)
UPDATE coffees SET image_key = '44c3458d43b80694c97273f85ccb73c8' WHERE id = 'C0FFEE05-0001-4000-8000-000000000001' AND image_key IS NULL;
-- Shokunin Coffee: Ana Restrepo (https://shokunin.coffee/product/ana-restrepo/)
UPDATE coffees SET image_key = '2c6b30a0c4607ae9c6ac385eb7351283' WHERE id = 'C0FFEE04-0016-4000-8000-000000000016' AND image_key IS NULL;
-- Shokunin Coffee: Argote Anaerobic (https://shokunin.coffee/product/argote-anaerobic/)
UPDATE coffees SET image_key = '11387bc8bfea8e9a8f2e3159f00ba3e8' WHERE id = 'C0FFEE04-0014-4000-8000-000000000014' AND image_key IS NULL;
-- Shokunin Coffee: Churupampa (https://shokunin.coffee/product/churupampa/)
UPDATE coffees SET image_key = '9fdf0467091fe1e42c0d63e652198d8c' WHERE id = 'C0FFEE04-0022-4000-8000-000000000022' AND image_key IS NULL;
-- Shokunin Coffee: Cultivares (https://shokunin.coffee/product/cultivares/)
UPDATE coffees SET image_key = 'd274305c92954cb1f85175542d796da4' WHERE id = 'C0FFEE04-0002-4000-8000-000000000002' AND image_key IS NULL;
-- Shokunin Coffee: Fausto Romo (https://shokunin.coffee/product/fausto-romo/)
UPDATE coffees SET image_key = '9c592cd91113c3380212081297963cb9' WHERE id = 'C0FFEE04-0009-4000-8000-000000000009' AND image_key IS NULL;
-- Shokunin Coffee: Fontana (https://shokunin.coffee/product/fontana/)
UPDATE coffees SET image_key = '2a1afcfa95484a8e74e39f284cd99c67' WHERE id = 'C0FFEE04-0012-4000-8000-000000000012' AND image_key IS NULL;
-- Shokunin Coffee: Keramo Natural (https://shokunin.coffee/product/keramo-natural/)
UPDATE coffees SET image_key = '6d026a6d58f5130d7a8ee91857641555' WHERE id = 'C0FFEE04-0020-4000-8000-000000000020' AND image_key IS NULL;
-- Shokunin Coffee: Kianamui (https://shokunin.coffee/product/kianamui/)
UPDATE coffees SET image_key = '81f704baa7a8d6e6474fcec8bb834c2c' WHERE id = 'C0FFEE04-0006-4000-8000-000000000006' AND image_key IS NULL;
-- Shokunin Coffee: La Villa (https://shokunin.coffee/product/la-villa/)
UPDATE coffees SET image_key = '5ebb9671537f1be0dde2fac6a0b39b65' WHERE id = 'C0FFEE04-0004-4000-8000-000000000004' AND image_key IS NULL;
-- Shokunin Coffee: Mae Chedi (https://shokunin.coffee/product/mae-chedi/)
UPDATE coffees SET image_key = 'c06535dec9e9eeffa1616e134e28c3c8' WHERE id = 'C0FFEE04-0007-4000-8000-000000000007' AND image_key IS NULL;
-- Shokunin Coffee: Mooleh Manay Excelsa (https://shokunin.coffee/product/mooleh-manay-excelsa/)
UPDATE coffees SET image_key = '8bc72a1e7eb9c500ba4c1a55205658a2' WHERE id = 'C0FFEE04-0008-4000-8000-000000000008' AND image_key IS NULL;
-- Shokunin Coffee: Passeio (https://shokunin.coffee/product/passeio/)
UPDATE coffees SET image_key = '05213eaa05aac484beda411e5a9f0ef2' WHERE id = 'C0FFEE04-0003-4000-8000-000000000003' AND image_key IS NULL;
-- Shokunin Coffee: Sironko (https://shokunin.coffee/product/sironko/)
UPDATE coffees SET image_key = 'f9f0d8699f2f225d4280e2cf249b2e6f' WHERE id = 'C0FFEE04-0013-4000-8000-000000000013' AND image_key IS NULL;
-- Man Met Bril Koffie: Blendy Blend (https://koffiekenner.com/en/products/blendy-blend-brazil)
UPDATE coffees SET image_key = '60f623414193106c3c6b2e56037939d4' WHERE id = 'C0FFEE01-0004-4000-8000-000000000004' AND image_key IS NULL;
-- Man Met Bril Koffie: Hotel Blend (https://koffiekenner.com/en/products/hotel-blend)
UPDATE coffees SET image_key = '0f4812bd6a67f5250a0f4148f47120e2' WHERE id = 'C0FFEE01-0006-4000-8000-000000000006' AND image_key IS NULL;
-- Man Met Bril Koffie: Hambella (https://koffiekenner.com/en/products/hambella)
UPDATE coffees SET image_key = '63a7c34cc7eaad6ea3485a91609fb706' WHERE id = 'C0FFEE01-0001-4000-8000-000000000001' AND image_key IS NULL;
