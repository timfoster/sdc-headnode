#!/bin/env node

/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/*
 * Copyright 2019 Joyent, Inc.
 */

 /*
  * Used as part of the path name where artifacts for the headnode build
  * are stored in Manta, emit a hypen separated list of the unique branch
  * names for this build, as defined by build.spec and build.spec.local.
  */
var util = require('util');

var lib_common = require('../lib/common');
var lib_buildspec = require('../lib/buildspec');

function main() {
    lib_buildspec.load_build_specs(lib_common.root_path('build.spec'),
        lib_common.root_path('build.spec.local'), function (err, bs) {
        if (err) {
            console.error('ERROR loading build specs: %s', err.stack);
            process.exit(3);
        }

        var branches = {};

        // get each of the build.spec sections that may have branch specifiers
        var zones = bs.get('zones');
        var files = bs.get('files');

        var bits_branch = bs.get('bits-branch', true);
        if (bits_branch !== undefined) {
            branches[bits_branch] = null;
        }

        function find_branches(branch_dic, component_dic, component_name) {
            Object.keys(component_dic).forEach(function find_branches(item) {
                var branch_name = bs.get(
                    util.format('%s|%s|branch', component_name, item), true);
                if (branch_name !== undefined) {
                    branch_dic[branch_name] = null;
                }
            });
        }
        find_branches(branches, zones, 'zones');
        find_branches(branches, files, 'files');

        var branch_string = Object.keys(branches).sort().join('-');
        if (branch_string.length !== 0) {
            console.log(branch_string);
        }
        process.exit(0);
    });
}

main();
