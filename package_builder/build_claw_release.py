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
from contextlib import contextmanager

DEFAULT_CLAW_REPOSITORY = 'https://github.com/claw-project/claw-compiler.git'
DEFAULT_CLAW_RELEASE = 'v2.0.2'
DEFAULT_C_COMPILER = '/usr/bin/gcc'
DEFAULT_CXX_COMPILER = '/usr/bin/g++'
DEFAULT_FC_COMPILER = '/usr/bin/gfortran'
DEFAULT_FC_COMPILER_MODULES = []
TMP_DIR = '/tmp'
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
    build_dir: Optional[str]
    cmake_modules: List[str]


def which(cmd: str, modules: List[str]=[]) -> str:
    if len(modules) == 0:
        return shutil.which(cmd)
    else:
        which_str = 'module purge && module load %s && which %s' % (' '.join(modules), cmd)
        res = run(which_str, shell=True, stdout=subprocess.PIPE).stdout.decode('utf-8').strip()
        return res


def parse_args(cmdline_args: List[str]=None) -> Args:
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
    parser.add_argument('-fm', '--fc-compiler-modules', type=str, nargs='*',
                        help='Fortran compiler modules')
    parser.add_argument('--ant-home-dir', type=str,
                        help='Apache Ant install dir')
    parser.add_argument('--build-dir', type=str,
                        help='Build directory')
    parser.add_argument('--disable-tests', action='store_true')
    parser.add_argument('-cm', '--cmake-modules', type=str, nargs='*',
                        help='Cmake modules')
    p_args = parser.parse_args(cmdline_args)
    fc_modules = []
    if p_args.fc_compiler_modules is not None:
        fc_modules += p_args.fc_compiler_modules
    cmake_modules = []
    if p_args.cmake_modules is not None:
        cmake_modules += p_args.cmake_modules
    args = Args(install_dir=p_args.install_dir,
                source_repo=p_args.source_repository,
                release_tag=p_args.release_tag,
                cc=which(p_args.c_compiler),
                cxx=which(p_args.cxx_compiler),
                fc=which(p_args.fc_compiler, fc_modules),
                fc_modules=fc_modules,
                ant_dir=p_args.ant_home_dir,
                disable_tests=p_args.disable_tests,
                build_dir=p_args.build_dir,
                cmake_modules=cmake_modules)
    return args


def file_exists(path: str) -> bool:
    return os.path.exists(path) and os.path.isfile(path)


def dir_exists(path: str) -> bool:
    return os.path.exists(path) and os.path.isdir(path)


@contextmanager
def prepare_dir(dir_path=None, parent_dir=None):
    if dir_path is not None:
        os.makedirs(dir_path, exist_ok=True)
        yield dir_path
    else:
        d = tempfile.TemporaryDirectory(dir=parent_dir)
        yield d.name
        d.cleanup()


def check_arguments(args: Args):
    assert file_exists(args.cc), 'C compiler "%s" not found' % args.cc
    assert file_exists(args.cxx), 'C++ compiler "%s" not found' % args.cxx
    assert file_exists(args.fc), 'Fortran compiler "%s" not found' % args.fc
    assert args.ant_dir is None or dir_exists(args.ant_dir), 'Ant dir "%s" not found' % args.ant_dir
    assert args.release_tag in SUPPORTED_RELEASES, 'Currently only the following releases are supported [%s]' % \
                                                   ', '.join(SUPPORTED_RELEASES)
    os.makedirs(args.install_dir, exist_ok=True)


def check_system():
    res = run(['cmake', '--version'], stdout=subprocess.PIPE)
    assert res.returncode == 0 or 'cmake version' not in res.stdout, 'cmake not found'


def setup_logging() -> log.Logger:
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
        f_path = join_path(src_dir, f_name)
        f_data = None
        with open(f_path, 'r') as f:
            f_data = f.read()
        f_data = f_data.replace('${CMAKE_Fortran_COMPILER}', '${CLAW_Fortran_COMPILER}')
        with open(f_path, 'w') as f:
            f.write(f_data)


def install_sanity_check(install_dir : str, modules_cmd : str):
    clawfc = join_path(install_dir, 'bin/clawfc')
    with tempfile.TemporaryDirectory(dir=TMP_DIR) as test_dir:
        test_in_file = join_path(test_dir, 'conftest.f90')
        with open(test_in_file, 'w') as f:
            f.writelines(['module conftest_module\n',
                          'end module'])
        test_cmd = modules_cmd + clawfc + ' -f -o conftest.claw.f90 conftest.f90'
        assert run(test_cmd, shell=True, cwd=test_dir).returncode == 0, 'claw run failed'
        out_file_path = join_path(test_dir, 'conftest.claw.f90')
        xmod_path = join_path(test_dir, 'conftest_module.xmod')
        assert file_exists(out_file_path), 'claw run failed'
        assert file_exists(xmod_path), 'claw run failed'


def main(cmdline_args: List[str]=None):
    log = setup_logging()
    args = parse_args(cmdline_args)
    log.info('Parsed input arguments...')
    for name, value in args._asdict().items():
        log.info('\t%s : %s' % (name, value))
    log.info('Checking input arguments...')
    check_arguments(args)
    #log.info('Checking system...')
    #check_system()
    log.info('Creating build dir')
    build_dir_args = {}
    if args.build_dir is None:
        build_dir_args['parent_dir'] = TMP_DIR
    else:
        build_dir_args['dir_path'] = args.build_dir
    with prepare_dir(**build_dir_args) as build_dir:
        os.chdir(build_dir)
        log.info('Checking out source...')
        run(['git', 'clone', args.source_repo])
        src_dir = join_path(build_dir, 'claw-compiler')
        os.chdir(src_dir)
        log.debug('\tSource dir : %s' % src_dir)
        assert run(['git', 'checkout', args.release_tag]).returncode == 0
        assert run(['git', 'submodule', 'init']).returncode == 0
        assert run(['git', 'submodule', 'update']).returncode == 0
        log.info('Patching source... ')
        patch_source(src_dir)
        log.info('Configuring build...')
        modules_cmd = ''
        modules = args.cmake_modules + args.fc_modules
        if len(modules) > 0:
            cmds = []
            cmds += ['module purge']
            for module in modules:
                cmds += ['module load %s' % module]
            modules_cmd = ' && '.join(cmds) + ' && '
        c_args = ['CC=%s' % args.cc, 'CXX=%s' % args.cxx]
        if args.ant_dir is not None:
            c_args += ['ANT_HOME=%s' % args.ant_dir]
        c_args += ['cmake', '-DCLAW_Fortran_COMPILER=%s' % args.fc, '-DCMAKE_INSTALL_PREFIX=%s' % args.install_dir]
        cmd = modules_cmd + ' '.join(c_args)
        assert run(cmd, shell=True).returncode == 0, 'Build configuration failed'
        log.info('Backing up old install...')
        backup_dir = args.install_dir + '.old'
        shutil.move(args.install_dir, backup_dir)
        try:
            log.info('Building...')
            cmd = modules_cmd + 'make -j'
            assert run(cmd, shell=True).returncode == 0, 'Build failed'
            if not args.disable_tests:
                log.info('Testing...')
                assert run(modules_cmd + 'make -j transformation test', shell=True).returncode == 0, 'Test failed'
            log.info('Installing...')
            assert run(['make', 'install']).returncode == 0, 'Install failed'
            log.info('Performing sanity check on install...')
            install_sanity_check(args.install_dir, modules_cmd)
            shutil.rmtree(backup_dir)
        except:
            log.error('Restoring old install')
            shutil.move(backup_dir, args.install_dir)


if __name__ == '__main__':
    main()
    sys.exit(RC.SUCCESS.value)
