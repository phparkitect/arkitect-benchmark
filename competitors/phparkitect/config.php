<?php

declare(strict_types=1);

use Arkitect\ClassSet;
use Arkitect\CLI\Config;
use Arkitect\Expression\ForClasses\NotDependsOnTheseNamespaces;
use Arkitect\Expression\ForClasses\ResideInOneOfTheseNamespaces;
use Arkitect\Rules\Rule;

/*
 * The cross-tool rule, expressed for phparkitect. See ../akeneo/RULE.md.
 */
return static function (Config $config): void {
    $srcDir = getenv('CROSS_TOOL_SRC_DIR') ?: __DIR__ . '/../../akeneo/src';

    $config->add(
        ClassSet::fromDir($srcDir),
        Rule::allClasses()
            ->that(new ResideInOneOfTheseNamespaces('Akeneo\*\Domain'))
            ->should(new NotDependsOnTheseNamespaces(['Symfony']))
            ->because('the domain layer must not depend on the framework')
    );
};
