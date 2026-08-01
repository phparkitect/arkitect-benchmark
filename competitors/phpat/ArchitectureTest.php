<?php

declare(strict_types=1);

use PHPat\Selector\Selector;
use PHPat\Test\Builder\Rule;
use PHPat\Test\PHPat;

/*
 * The same three rules as ../phparkitect/config.php and ../deptrac/depfile.yaml.
 * The naming rule is left out — see ../README.md.
 */
final class ArchitectureTest
{
    public function test_http_foundation_no_heavy_deps(): Rule
    {
        return PHPat::rule()
            ->classes(Selector::inNamespace('Symfony\Component\HttpFoundation'))
            ->shouldNotDependOn()
            ->classes(
                Selector::inNamespace('Doctrine'),
                Selector::inNamespace('Twig'),
                Selector::inNamespace('Monolog'),
                Selector::inNamespace('Psr\Log'),
            );
    }

    public function test_event_dispatcher_no_heavy_deps(): Rule
    {
        return PHPat::rule()
            ->classes(Selector::inNamespace('Symfony\Component\EventDispatcher'))
            ->shouldNotDependOn()
            ->classes(
                Selector::inNamespace('Doctrine'),
                Selector::inNamespace('Twig'),
            );
    }

    public function test_dependency_injection_no_http(): Rule
    {
        return PHPat::rule()
            ->classes(Selector::inNamespace('Symfony\Component\DependencyInjection'))
            ->shouldNotDependOn()
            ->classes(
                Selector::inNamespace('Symfony\Component\HttpFoundation'),
                Selector::inNamespace('Symfony\Component\HttpKernel'),
            );
    }
}
