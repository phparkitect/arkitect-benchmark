<?php

declare(strict_types=1);

use Arkitect\ClassSet;
use Arkitect\CLI\Config;
use Arkitect\Expression\ForClasses\HaveNameMatching;
use Arkitect\Expression\ForClasses\NotDependsOnTheseNamespaces;
use Arkitect\Expression\ForClasses\ResideInOneOfTheseNamespaces;
use Arkitect\Rules\Rule;

return static function (Config $config): void {
    $srcDir = getenv('BENCHMARK_SRC_DIR') ?: __DIR__ . '/symfony/src';

    $classSet = ClassSet::fromDir($srcDir);

    $rules = [];

    // Rule 1: Classes in HttpFoundation do not depend on namespaces outside Symfony
    $rules[] = Rule::allClasses()
        ->that(new ResideInOneOfTheseNamespaces('Symfony\Component\HttpFoundation'))
        ->should(new NotDependsOnTheseNamespaces(
            ['Doctrine', 'Twig', 'Monolog', 'Psr\Log']
        ))
        ->because('HttpFoundation should remain framework-agnostic and not pull in heavy dependencies');

    // Rule 2: Classes in Console\Command namespace must have names ending in "Command"
    $rules[] = Rule::allClasses()
        ->that(new ResideInOneOfTheseNamespaces('Symfony\Component\Console\Command'))
        ->should(new HaveNameMatching('*Command'))
        ->because('Console command classes must follow the Command suffix convention');

    // Rule 3: Classes in EventDispatcher do not depend on namespaces outside Symfony
    $rules[] = Rule::allClasses()
        ->that(new ResideInOneOfTheseNamespaces('Symfony\Component\EventDispatcher'))
        ->should(new NotDependsOnTheseNamespaces(
            ['Doctrine', 'Twig']
        ))
        ->because('EventDispatcher should stay decoupled from persistence and templating layers');

    $config->add($classSet, ...$rules);
};
