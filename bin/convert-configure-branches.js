#!/bin/env node

/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/*
 * Copyright 2019 Joyent, Inc.
 */

var mod_fs = require('fs');

/*
 * This script loads a build.spec file, then lazily parses a
 * configure-branches file and emits a build.spec.local with that data.
 * There is minimal error checking here.
 */

function
main()
{
    mod_fs.readFile('build.spec', 'utf-8', function readbs(err, bs_file) {
        if (err) {
            console.error('Error loading build specs: %s', err.stack);
            process.exit(3);
        }

        var bs_data = JSON.parse(bs_file);
        var known_zones = Object.keys(bs_data.zones);
        var known_files = Object.keys(bs_data.files);
        var out_buildspec = {};

        mod_fs.readFile('configure-branches', 'utf-8',
                function read(cerr, data) {
            if (cerr) {
                console.error(
                    'Error reading configure-branches file: %s', err);
                process.exit(3);
            }
            var vals = data.split('\n');
            for (var i=0; i < vals.length; i++) {
                var line = vals[i].trim();
                if (line.length === 0) {
                    continue;
                }

                // ignore comments
                if (line.lastIndexOf('#') === 0) {
                    continue;
                }

                var keyval = line.split(':');
                if (keyval.length !== 2) {
                    console.error('Line has more than two fields: %s', line);
                    process.exit(3);
                }

                var key = keyval[0].trim();
                var val = keyval[1].trim();

                // zones
                if (known_zones.lastIndexOf(key) > -1) {
                    if (out_buildspec.zones === undefined) {
                        out_buildspec.zones = {};
                    }
                    out_buildspec.zones[key] = {'branch': val};

                // files
                } else if (known_files.lastIndexOf(key) > -1) {
                    if (out_buildspec.files === undefined) {
                        out_buildspec.files = {};
                    }
                    out_buildspec.files[key] = {'branch': val};
                    if (key === 'platform') {
                        out_buildspec.files['platboot'] = {'branch': val};
                    } else if (key === 'platboot') {
                        out_buildspec.files['platform'] = {'branch': val};
                    }

                // any other fields
                } else {
                    if (bs_data[key] === undefined) {
                        console.error(
                            'Unknown key in configure-branches file, ' +
                            'line %s :%s', i+1, key);
                        process.exit(3);
                    }
                    out_buildspec[key] = val;
                }
            }
            console.log(JSON.stringify(out_buildspec, null, 4));
        });
    });
}

main();
