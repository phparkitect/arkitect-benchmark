<?php

declare(strict_types=1);

use PHPat\Selector\Selector;
use PHPat\Test\Builder\Rule;
use PHPat\Test\PHPat;

/*
 * The cross-tool rule, expressed for phpat. See ../akeneo/RULE.md.
 */
final class ArchitectureTest
{
    public function test_domain_does_not_depend_on_the_framework(): Rule
    {
        return PHPat::rule()
            ->classes(Selector::inNamespace('/^Akeneo\\\\.*\\\\Domain\\\\/', true))
            ->shouldNotDependOn()
            ->classes(Selector::inNamespace('Symfony'));
    }
}
