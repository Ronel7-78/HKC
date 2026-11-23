<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::view('/confidentialite', 'legal.privacy')->name('legal.privacy');
Route::view('/conditions-utilisation', 'legal.terms')->name('legal.terms');
Route::view('/suppression-compte', 'legal.account-deletion')->name('legal.account-deletion');
