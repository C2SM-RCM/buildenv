#!/usr/bin/env python3
#-*- coding: utf-8 -*-

__author__ = "Mikhail Zhigun"
__copyright__ = "Copyright 2020, MeteoSwiss"

""" This module builds, tests and installs CLAW compiler
"""

import sys, os, argparse, logging as log, shutil, tempfile, subprocess
from os.path import join as join_path, realpath as real_path
assert sys.version_info[0] >= 3 and sys.version_info[1] >= 5, 'Python >= 3.5 is required'
from enum import Enum
from typing import NamedTuple, List, Optional
from subprocess import run

DEFAULT_CLAW_REPOSITORY = 'https://github.com/claw-project/claw-compiler.git'
DEFAULT_CLAW_RELEASE = 'v2.0.2'
DEFAULT_C_COMPILER = '/usr/bin/gcc'
DEFAULT_CXX_COMPILER = '/usr/bin/g++'
DEFAULT_FC_COMPILER = '/usr/bin/gfortran'
DEFAULT_FC_COMPILER_MODULES = []
TMP_DIR = '/dev/shm'
SUPPORTED_RELEASES = ('v2.0.1', 'v2.0.2')


class ReturnCode(Enum):
    SUCCESS = 0
    FAILURE = 1


RC = ReturnCode


class Args(NamedTuple):
    install_dir: str
    source_repo: str
    release_tag: str
    cc: str
    cxx: str
    fc: str
    fc_modules: List[str]
    ant_dir: Optional[str]
    disable_tests: bool


def parse_args() -> Args:
    parser = argparse.ArgumentParser(description='CLAW installer')
    parser.add_argument('-i', '--install-dir', type=str, required=True,
                        help='Path to target install directory')
    parser.add_argument('--source-repository', type=str, default=DEFAULT_CLAW_REPOSITORY,
                        help='Git repository with source')
    parser.add_argument('--release-tag', type=str, default=DEFAULT_CLAW_RELEASE,
                        help='Git release tag')
    parser.add_argument('--c-compiler', type=str, default=DEFAULT_C_COMPILER,
                        help='Path to C compiler executable')
    parser.add_argument('--cxx-compiler', type=str, default=DEFAULT_CXX_COMPILER,
                        help='Path to C++ compiler executable')
    parser.add_argument('-f', '--fc-compiler', type=str, default=DEFAULT_FC_COMPILER,
                        help='Path to Fortran compiler executable')
    parser.add_argument('-fm', '--fc-compiler-module', type=str, nargs='*',
                        help='Fortran compiler module')
    parser.add_argument('--ant-home-dir', type=str,
                        help='Apache Ant install dir')
    parser.add_argument('--disable-tests', action='store_true')
    p_args = parser.parse_args()
    fc_modules = []
    if p_args.fc_compiler_module is not None:
        fc_modules += p_args.fc_compiler_module
    args = Args(install_dir=p_args.install_dir,
                source_repo=p_args.source_repository,
                release_tag=p_args.release_tag,
                cc=shutil.which(p_args.c_compiler),
                cxx=shutil.which(p_args.cxx_compiler),
                fc=shutil.which(p_args.fc_compiler),
                fc_modules=fc_modules,
                ant_dir=p_args.ant_home_dir,
                disable_tests=p_args.disable_tests)
    return args


def file_exists(path: str):
    return os.path.exists(path) and os.path.isfile(path)


def dir_exists(path: str):
    return os.path.exists(path) and os.path.isdir(path)


def check_arguments(args: Args):
    assert file_exists(args.cc), 'C compiler "%s" not found' % args.cc
    assert file_exists(args.cxx), 'C++ compiler "%s" not found' % args.cxx
    assert file_exists(args.fc), 'Fortran compiler "%s" not found' % args.fc
    assert args.ant_dir is None or dir_exists(args.ant_home_dir), 'Ant dir "%s" not found' % args.ant_dir
    assert args.release_tag in SUPPORTED_RELEASES, 'Currently only the following releases are supported [%s]' % \
                                                   ', '.join(SUPPORTED_RELEASES)
    os.makedirs(args.install_dir, exist_ok=True)


def check_system():
    res = run(['cmake', '--version'], stdout=subprocess.PIPE)
    assert res.returncode == 0 or 'cmake version' not in res.stdout, 'cmake not found'


def setup_logging():
    logger = log.getLogger("CLAW_INSTALLER")
    logger.setLevel(log.DEBUG)
    formatter = log.Formatter('%(asctime)s : %(levelname)s : %(message)s')
    stream_handler = log.StreamHandler()
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)
    return logger


def patch_source(src_dir : str):
    files = ('CMakeLists.txt', 'properties.cmake', 'cmake/omni_compiler.cmake')
    for f_name in files:
        f_path = os.path.join(src_dir, f_name)
        f_data = None
        with open(f_path, 'r') as f:
            f_data = f.read()
        f_data = f_data.replace('${CMAKE_Fortran_COMPILER}', '${CLAW_Fortran_COMPILER}')
        with open(f_path, 'w') as f:
            f.write(f_data)


if __name__ == '__main__':
    log = setup_logging()
    args = parse_args()
    log.info('Parsed input arguments...')
    for name, value in args._asdict().items():
        log.info('\t%s : %s' % (name, value))
    log.info('Checking input arguments...')
    check_arguments(args)
    log.info('Checking system...')
    check_system()
    log.info('Creating build dir')
    with tempfile.TemporaryDirectory(dir=TMP_DIR) as build_dir:
        os.chdir(build_dir)
        log.info('Checking out source...')
        run(['git', 'clone', args.source_repo])
        src_dir = os.path.join(build_dir, 'claw-compiler')
        os.chdir(src_dir)
        log.debug('\tSource dir : %s' % src_dir)
        run(['git', 'checkout', args.release_tag])
        run(['git', 'submodule', 'init'])
        run(['git', 'submodule', 'update'])
        log.info('Patching source... ')
        patch_source(src_dir)
        log.info('Configuring build...')
        module_cmd = ''
        if len(args.fc_modules) > 0:
            cmds = []
            cmds += ['module purge']
            for module in args.fc_modules:
                cmds += ['module load %s' % module]
            module_cmd = ' && '.join(cmds) + ' && '
        c_args = ['CC=%s' % args.cc, 'CXX=%s' % args.cxx]
        if args.ant_dir is not None:
            c_args += ['ANT_HOME=%s' % args.ant_dir]
        c_args += ['cmake', '-DCLAW_Fortran_COMPILER=%s' % args.fc, '-DCMAKE_INSTALL_PREFIX=%s' % args.install_dir]
        cmd = module_cmd + ' '.join(c_args)
        assert run(cmd, shell=True).returncode == 0, 'Build configuration failed'
        log.info('Backing up old install...')
        backup_dir = args.install_dir + '.old'
        shutil.move(args.install_dir, backup_dir)
        try:
            log.info('Building...')
            cmd = module_cmd + 'make -j'
            assert run(cmd, shell=True).returncode == 0, 'Build failed'
            if not args.disable_tests:
                log.info('Testing...')
                assert run(['make', '-j', 'transformation', 'test']).returncode == 0, 'Test failed'
            log.info('Installing...')
            assert run(['make', 'install']).returncode == 0, 'Install failed'
            shutil.rmtree(backup_dir)
        except:
            log.error('Restoring old install')
            shutil.move(backup_dir, args.install_dir)
    sys.exit(RC.SUCCESS.value)
