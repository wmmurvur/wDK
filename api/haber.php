<?php
/*
 * Türkiye ziyareti haber listesi. Ana sayfadaki formdan gelen kaydı, web kökünün DIŞINDA bir CSV dosyasına ekler
 * (yayın her seferinde web kökünü yenilese de kayıtlar kaybolmaz) ve sahibine kısa bir e-posta atar.
 * Kayıtların yeri: public_html'in bir üstündeki haber-listesi/kayitlar.csv (Hostinger'da dosya yöneticisinden görülür).
 */
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function cevap(int $kod, array $govde): void { http_response_code($kod); echo json_encode($govde, JSON_UNESCAPED_UNICODE); exit; }
function al(string $ad, int $uzunluk): string {
    $deger = trim(strip_tags((string)($_POST[$ad] ?? '')));
    $deger = preg_replace('/[\r\n\t]+/u', ' ', $deger) ?? '';
    return mb_substr($deger, 0, $uzunluk);
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') cevap(405, ['ok' => false]);
// bal tuzağı: insanlar görmez, botlar doldurur; bota başarılı gibi görünür
if (al('web', 200) !== '') cevap(200, ['ok' => true]);

$ad = al('ad', 80);
$sehir = al('sehir', 60);
$iletisim = al('iletisim', 120);
$riza = ($_POST['riza'] ?? '') === 'evet';
if ($ad === '' || $iletisim === '' || !$riza) cevap(422, ['ok' => false, 'hata' => 'eksik']);

$dizin = dirname(__DIR__, 2) . '/haber-listesi';
if (!is_dir($dizin) && !@mkdir($dizin, 0700, true)) {
    // web kökünün dışına yazılamıyorsa kökün içinde, dışarıdan erişime kapalı bir klasör
    $dizin = dirname(__DIR__) . '/_haber-listesi';
    if (!is_dir($dizin)) { @mkdir($dizin, 0700, true); @file_put_contents($dizin . '/.htaccess', "Require all denied\nDeny from all\n"); }
}
$dosya = $dizin . '/kayitlar.csv';
$yeni = !file_exists($dosya);
$fh = @fopen($dosya, 'ab');
if (!$fh) cevap(500, ['ok' => false, 'hata' => 'yazilamadi']);
flock($fh, LOCK_EX);
if ($yeni) fputcsv($fh, ['tarih', 'ad', 'sehir', 'iletisim', 'riza']);
// hesap tablosunda formül olarak çalışmasın diye = + - @ ile başlayan değerlerin önüne kesme işareti
$guvenli = fn(string $d): string => preg_match('/^[=+\-@]/u', $d) ? "'" . $d : $d;
fputcsv($fh, [date('c'), $guvenli($ad), $guvenli($sehir), $guvenli($iletisim), 'evet']);
flock($fh, LOCK_UN);
fclose($fh);

@mail('contact@pebuc.site', '=?UTF-8?B?' . base64_encode('Haber listesine yeni kayıt') . '?=',
    "Ad: $ad\nŞehir: $sehir\nİletişim: $iletisim\n",
    "From: site@pebuc.site\r\nContent-Type: text/plain; charset=UTF-8");

cevap(200, ['ok' => true]);
