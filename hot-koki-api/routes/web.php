<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::view('/paiements/orange/retour', 'payments.orange-result', [
    'success' => true,
])->name('payments.orange.return');

Route::view('/paiements/orange/annulation', 'payments.orange-result', [
    'success' => false,
])->name('payments.orange.cancel');

Route::view('/confidentialite', 'legal.privacy')->name('legal.privacy');
Route::view('/conditions-utilisation', 'legal.terms')->name('legal.terms');
