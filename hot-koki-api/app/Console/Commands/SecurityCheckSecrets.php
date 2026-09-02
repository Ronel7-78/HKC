<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Process;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use SplFileInfo;

class SecurityCheckSecrets extends Command
{
    protected $signature = 'security:check-secrets';

    protected $description = 'Vérifier qu’aucun secret serveur n’est exposé dans les fichiers partagés';

    public function handle(): int
    {
        $errors = [];
        $this->inspectPublicDirectory($errors);
        $this->inspectGitFiles($errors);
        $this->inspectEnvironmentPermissions($errors);

        if ($errors !== []) {
            foreach (array_unique($errors) as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        $this->info('Aucun secret serveur détecté dans les fichiers partagés.');

        return self::SUCCESS;
    }

    private function inspectEnvironmentPermissions(array &$errors): void
    {
        if (! app()->environment('production') || ! is_file(base_path('.env'))) {
            return;
        }

        $permissions = fileperms(base_path('.env'));
        if ($permissions === false || ($permissions & 0077) !== 0) {
            $errors[] = 'En production, .env doit être lisible et modifiable uniquement par son propriétaire (chmod 600).';
        }
    }

    private function inspectPublicDirectory(array &$errors): void
    {
        $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(public_path()));

        /** @var SplFileInfo $file */
        foreach ($iterator as $file) {
            if (! $file->isFile()) {
                continue;
            }

            $name = mb_strtolower($file->getFilename());
            if (str_starts_with($name, '.env') || preg_match('/\.(sql|sqlite|pem|key|p12)$/', $name)) {
                $errors[] = 'Fichier sensible présent dans public/ : '.$file->getFilename();
            }
        }
    }

    private function inspectGitFiles(array &$errors): void
    {
        $rootResult = Process::path(base_path())->run(['git', 'rev-parse', '--show-toplevel']);
        if (! $rootResult->successful()) {
            $this->warn('Dépôt Git absent : contrôle des fichiers suivis ignoré.');

            return;
        }

        $root = trim($rootResult->output());
        $filesResult = Process::path($root)->run(['git', 'ls-files', '-z']);
        if (! $filesResult->successful()) {
            $errors[] = 'Impossible de contrôler les fichiers suivis par Git.';

            return;
        }

        $files = array_filter(explode("\0", $filesResult->output()));
        $secrets = $this->configuredSecrets();

        foreach ($files as $relativePath) {
            $name = mb_strtolower(basename($relativePath));
            if (! str_ends_with($name, '.example') && (
                str_starts_with($name, '.env')
                || preg_match('/\.(sql|sqlite|pem|key|p12)$/', $name)
            )) {
                $errors[] = 'Fichier sensible suivi par Git : '.$relativePath;
            }

            if (! preg_match('/\.(php|dart|js|ts|json|ya?ml|xml|md)$/i', $relativePath)) {
                continue;
            }

            $absolutePath = $root.DIRECTORY_SEPARATOR.$relativePath;
            $contents = @file_get_contents($absolutePath);
            if ($contents === false) {
                continue;
            }

            foreach ($secrets as $label => $secret) {
                if (str_contains($contents, $secret)) {
                    $errors[] = $label.' a été copié dans un fichier suivi par Git : '.$relativePath;
                }
            }
        }
    }

    private function configuredSecrets(): array
    {
        return collect([
            'APP_KEY' => config('app.key'),
            'DB_PASSWORD' => config('database.connections.'.config('database.default').'.password'),
            'MAIL_PASSWORD' => config('mail.mailers.smtp.password'),
            'MTN_MOMO_SUBSCRIPTION_KEY' => config('services.mtn_momo.subscription_key'),
            'MTN_MOMO_API_KEY' => config('services.mtn_momo.api_key'),
            'ORANGE_MONEY_CLIENT_SECRET' => config('services.orange_money.client_secret'),
            'ORANGE_MONEY_MERCHANT_KEY' => config('services.orange_money.merchant_key'),
        ])->filter(fn ($value) => is_string($value) && mb_strlen($value) >= 12)->all();
    }
}
