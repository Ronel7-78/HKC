<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Pdo\Mysql;
use Throwable;

class DatabaseSecurityCheck extends Command
{
    protected $signature = 'security:check-database';

    protected $description = 'Vérifier que le compte MySQL applicatif respecte le moindre privilège';

    public function handle(): int
    {
        if (config('database.default') !== 'mysql') {
            $this->warn('Contrôle ignoré : la connexion active n’est pas MySQL.');

            return self::SUCCESS;
        }

        $connection = config('database.connections.mysql');
        $errors = [];
        $database = (string) ($connection['database'] ?? '');
        $username = (string) ($connection['username'] ?? '');
        $host = (string) ($connection['host'] ?? '');
        $socket = (string) ($connection['unix_socket'] ?? '');
        $systemDatabases = ['information_schema', 'mysql', 'performance_schema', 'sys'];

        if ($username === '' || mb_strtolower($username) === 'root') {
            $errors[] = 'Le compte applicatif MySQL ne doit jamais être root.';
        }
        if ($database === '' || in_array(mb_strtolower($database), $systemDatabases, true)) {
            $errors[] = 'Laravel doit utiliser une base applicative dédiée.';
        }
        if ($socket === '' && ! in_array($host, ['127.0.0.1', 'localhost', '::1'], true)) {
            $sslCa = $connection['options'][Mysql::ATTR_SSL_CA] ?? null;
            if (blank($sslCa)) {
                $errors[] = 'Une base MySQL distante doit obligatoirement utiliser un certificat CA TLS.';
            }
        }

        if ($errors !== []) {
            foreach ($errors as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        try {
            $rows = DB::select('SHOW GRANTS FOR CURRENT_USER');
            $identity = DB::selectOne('SELECT DATABASE() AS current_database, CURRENT_USER() AS current_user');
        } catch (Throwable) {
            $this->error('Impossible de vérifier les privilèges du compte MySQL applicatif.');

            return self::FAILURE;
        }

        if (($identity->current_database ?? null) !== $database) {
            $this->error('La connexion active ne cible pas la base MySQL configurée.');

            return self::FAILURE;
        }

        $grants = implode("\n", array_map(
            fn (object $row) => implode(' ', array_values((array) $row)),
            $rows,
        ));
        $dangerous = [
            'ALL PRIVILEGES' => '/\bALL PRIVILEGES\b/i',
            'GRANT OPTION' => '/\bGRANT OPTION\b/i',
            'FILE' => '/\bFILE\b/i',
            'PROCESS' => '/\bPROCESS\b/i',
            'SUPER' => '/\bSUPER\b/i',
            'CREATE USER' => '/\bCREATE USER\b/i',
            'SHUTDOWN' => '/\bSHUTDOWN\b/i',
            'RELOAD' => '/\bRELOAD\b/i',
        ];
        $found = array_keys(array_filter(
            $dangerous,
            fn (string $pattern) => preg_match($pattern, $grants) === 1,
        ));

        if ($found !== []) {
            $this->error('Privilèges MySQL excessifs détectés : '.implode(', ', $found).'.');
            $this->line('Le compte Laravel doit être limité à SELECT, INSERT, UPDATE et DELETE sur sa base.');

            return self::FAILURE;
        }

        $this->info('Les privilèges MySQL du compte applicatif sont limités.');

        return self::SUCCESS;
    }
}
