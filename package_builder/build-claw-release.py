#!/usr/bin/env python3
#-*- coding: utf-8 -*-

__author__ = "Mikhail Zhigun"
__copyright__ = "Copyright 2020, MeteoSwiss"

""" This module builds, tests and installs CLAW compiler
"""

import sys, os, argparse, logging as log, shutil
from os.path import join as join_path, realpath as real_path
assert sys.version_info[0] >= 3 and sys.version_info[1] >= 5, 'Python >= 3.5 is required'
from enum import Enum
from typing import NamedTuple, List, Optional

DEFAULT_CLAW_REPOSITORY = 'https://github.com/claw-project/claw-compiler.git'
DEFAULT_CLAW_RELEASE = 'v2.0.2'
DEFAULT_C_COMPILER = '/usr/bin/gcc'
DEFAULT_CXX_COMPILER = '/usr/bin/g++'
DEFAULT_FC_COMPILER = '/usr/bin/gfortran'
DEFAULT_FC_COMPILER_MODULES = []
TMP_DIR = '/dev/shm'


class ReturnCode(Enum):
    SUCCESS = 0
    FAILURE = 1


RC = ReturnCode


class Args(NamedTuple):
    install_dir: str
    source_repo: str
    release_tag: str
    c: str
    cxx: str
    fc: str
    fc_modules: List[str]
    ant_dir: Optional[str]


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
    p_args = parser.parse_args()
    args = Args(install_dir=p_args.install_dir,
                source_repo=p_args.source_repository,
                release_tag=p_args.release_tag,
                c=shutil.which(p_args.c_compiler),
                cxx=shutil.which(p_args.cxx_compiler),
                fc=shutil.which(p_args.fc_compiler),
                fc_modules=p_args.fc_compiler_module,
                ant_dir=p_args.ant_home_dir)
    return args


def file_exists(path: str):
    return os.path.exists(path) and os.path.isfile(path)


def dir_exists(path: str):
    return os.path.exists(path) and os.path.isdir(path)


def verify_arguments(args: Args):
    assert file_exists(args.c), 'C compiler "%s" not found' % args.c
    assert file_exists(args.cxx), 'C++ compiler "%s" not found' % args.cxx
    assert file_exists(args.fc), 'Fortran compiler "%s" not found' % args.fc
    assert args.ant_dir is None or dir_exists(args.ant_home_dir), 'Ant dir "%s" not found' % args.ant_dir
    os.makedirs(args.install_dir, exist_ok=True)


def setup_logging():
    log.basicConfig(level=log.INFO)
    logger = log.getLogger("CLAW_INSTALLER")
    formatter = log.Formatter('%(asctime)s - %(name)s - %(message)s')
    log.setF
    stream_handler = log.StreamHandler()
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)
    print(logger.handlers)
    logger.removeHandler(logger.handlers[0])
    return logger


if __name__ == '__main__':
    log = setup_logging()
    args = parse_args()
    log.info('Parsed input arguments...')
    for name, value in args._asdict().items():
        log.info('%s : %s' % (name, value))
    log.info('Checking input arguments...')
    sys.exit(RC.SUCCESS.value)
