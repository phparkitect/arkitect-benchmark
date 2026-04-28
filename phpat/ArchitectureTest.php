<?php

declare(strict_types=1);

use PHPat\Selector\Selector;
use PHPat\Test\Builder\Rule;
use PHPat\Test\PHPat;

final class ArchitectureTest
{
    // Rule 1: HttpFoundation does not depend on heavy external libs
    public function test_http_foundation_no_heavy_deps(): Rule
    {
        return PHPat::rule()
            ->classes(Selector::inNamespace('Symfony\Component\HttpFoundation'))
            ->cannotDependOn()
            ->classes(
                Selector::inNamespace('Doctrine'),
                Selector::inNamespace('Twig'),
                Selector::inNamespace('Monolog'),
                Selector::inNamespace('Psr\Log'),
            );
    }

    // Rule 3: EventDispatcher does not depend on persistence/templating
    public function test_event_dispatcher_no_heavy_deps(): Rule
    {
        return PHPat::rule()
            ->classes(Selector::inNamespace('Symfony\Component\EventDispatcher'))
            ->cannotDependOn()
            ->classes(
                Selector::inNamespace('Doctrine'),
                Selector::inNamespace('Twig'),
            );
    }

    // Rule 4: DependencyInjection does not depend on HTTP layer
    public function test_dependency_injection_no_http(): Rule
    {
        return PHPat::rule()
            ->classes(Selector::inNamespace('Symfony\Component\DependencyInjection'))
            ->cannotDependOn()
            ->classes(
                Selector::inNamespace('Symfony\Component\HttpFoundation'),
                Selector::inNamespace('Symfony\Component\HttpKernel'),
            );
    }
}
