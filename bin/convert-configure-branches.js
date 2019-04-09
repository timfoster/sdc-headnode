#!/usr/bin/env node

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
 * This script loads a build.spec file, then parses a configure-branches file
 * and emits a build.spec.local with that data. There is minimal error checking
 * here.
 *
 * The 'configure-branches' file is assumed to consist of lines of
 * colon-separated component:branch pairs, and that component names are not
 * allowed to contain colons. Comments are allowed, by starting a line with
 * a '#' character.
 *
 * Duplicate keys in configure-branches are not allowed. Some 'files'
 * components should have matching branch values, so we enforce that.
 */

function main() {
    mod_fs.readFile('build.spec', 'utf-8', function readbs(err, bs_file) {
        if (err) {
            console.error('Error loading build.spec file: %s', err);
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

                // we're not using split() because we want exactly two fields
                // but don't want to throw away branch names which may include
                // colons.
                var colon_index = line.indexOf(':');
                if (colon_index === line.length - 1 || colon_index === -1) {
                    console.error(
                        'Expected key:val pair on line %s, got: %s', i + 1,
                        line);
                    process.exit(3);
                }
                var key = line.slice(0, colon_index).trim();
                var val = line.slice(colon_index + 1, line.length).trim();

                if (key.length === 0 || val.length === 0) {
                    console.error(
                        'Invalid key/val pair on line %s: %s', i + 1, line);
                    process.exit(3);
                }

                // zones
                if (known_zones.lastIndexOf(key) > -1) {
                    if (out_buildspec.zones === undefined) {
                        out_buildspec.zones = {};
                    }
                    if (out_buildspec.zones[key] === undefined) {
                        out_buildspec.zones[key] = {'branch': val};
                    } else {
                        console.log(out_buildspec.zones[key]);
                        console.error(
                            'Duplicate key on line %s: %s', i + 1, line);
                        process.exit(3);
                    }

                // files
                } else if (known_files.lastIndexOf(key) > -1) {
                    if (out_buildspec.files === undefined) {
                        out_buildspec.files = {};
                    }
                    if (out_buildspec.files[key] === undefined) {
                        out_buildspec.files[key] = {'branch': val};
                    } else {
                        console.error(
                            'Duplicate key on line %s: %s', i + 1, line);
                        process.exit(3);
                    }

                    // some files components should have the same branch set
                    // if either appear in the configure-branches file.
                    var same_branches = [
                        ['platform', 'platboot'],
                        ['agents', 'agents_md5']
                    ];
                    same_branches.forEach(function dup(dup_pair) {
                        if (dup_pair.indexOf(key) !== -1) {
                            console.error(
                                'Note: setting common branch for %s', dup_pair);
                            dup_pair.forEach(function set_val(comp) {
                                out_buildspec.files[comp] = {'branch': val};
                            });
                        }
                    });

                // any other fields
                } else {
                    if (bs_data[key] === undefined) {
                        console.error(
                            'Unknown build.spec key in configure-branches ' +
                            'file, line %s: %s', i + 1, key);
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