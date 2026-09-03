<?php
require '/var/www/html/vendor/autoload.php';
$app = require_once '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$compose = file_get_contents('/tmp/sunset-compose.yml');
$s = App\Models\Service::where('uuid', 'b0n1oc2fcrzbgdco838ezm1i')->first();
if (!$s) {
    fwrite(STDERR, "service not found\n");
    exit(1);
}
$s->docker_compose_raw = $compose;
$s->save();
echo "saved compose (" . strlen($compose) . " bytes)\n";
