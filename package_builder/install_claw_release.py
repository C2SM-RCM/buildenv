#!/usr/bin/env python3
#-*- coding: utf-8 -*-

__author__ = "Mikhail Zhigun"
__copyright__ = "Copyright 2020, MeteoSwiss"

""" This code manages CLAW release installation. It is supposed to be run from corresponding Jenkins plan.
"""

import os, shutil
from os.path import join as join_path
from typing import List, Optional
from build_claw_release import main as install, dir_exists, file_exists


RELEASES = ('2.0.1', '2.0.2')
COMPILERS = ('gcc', 'pgi')
MACHINES = ('daint', 'tsa', 'ubuntu20')


def link_exists(path: str) -> bool:
    return os.path.exists(path) and os.path.islink(path)


def get_c_compiler(machine: str, compiler: str) -> str:
    return '/usr/bin/gcc'


def get_cxx_compiler(machine: str, compiler: str) -> str:
    return '/usr/bin/g++'


def get_fc_compiler(machine: str, compiler: str) -> str:
    if compiler == 'gcc':
        return '/usr/bin/gfortran'
    elif compiler == 'pgi':
        fc = {'daint' : 'ftn',
              'tsa' : 'pgfortran',
              'ubuntu20' : '/opt/pgi/linux86-64/19.10/bin/pgfortran'}.get(machine)
        assert fc is not None, 'Compiler "%s" unsupported on machine "%s"' % (compiler, machine)
        return fc
    else:
        assert False, 'Unsupported compiler'


def get_fc_compiler_modules(machine: str, compiler: str) -> List[str]:
    if compiler == 'gcc':
        return []
    elif compiler == 'pgi':
        fc_modules = {'daint' : ['PrgEnv-pgi', 'pgi/20.1.1'],
                      'tsa' : ['PrgEnv-pgi/19.9', 'pgi/19.9-gcc-8.3.0'],
                      'ubuntu20' : []}.get(machine)
        assert fc_modules is not None, 'Compiler "%s" unsupported on machine "%s"' % (compiler, machine)
        return fc_modules
    else:
        assert False, 'Unsupported compiler'


def get_env_var(name: str):
    val = os.environ.get(name)
    assert val is not None, 'Required environment var "%s" not set. Are you running the script from Jenkins?' % name
    return val


def get_top_install_dir(machine: str, release: str, compiler: str) -> str:
    if machine == 'ubuntu20':
        return join_path('/data/software/claw-release', compiler)
    elif machine in ('daint', 'tsa'):
        return join_path('/project/c14/install', machine, 'claw', compiler)
    else:
        assert False, 'Unknown machine'


def get_ant_dir(machine: str) -> Optional[str]:
    if machine == 'ubuntu20':
        return None
    elif machine == 'daint':
        return '/project/c14/install/daint/ant/apache-ant-1.10.2'
    elif machine == 'tsa':
        return '/project/c14/install/arolla/ant/apache-ant-1.10.2'
    else:
        assert False, 'Unknown machine'


if __name__ == '__main__':
    RELEASE = get_env_var('release')
    COMPILER = get_env_var('compiler')
    MACHINE = get_env_var('slave')
    DISABLE_TESTS = os.environ.get('disable_tests') is not None
    assert RELEASE in RELEASES, 'Unsupported release'
    assert COMPILER in COMPILERS, 'Unsupported compiler'
    assert MACHINE in MACHINES, 'Unsupported machine'
    cc = get_c_compiler(MACHINE, COMPILER)
    cxx = get_cxx_compiler(MACHINE, COMPILER)
    fc = get_fc_compiler(MACHINE, COMPILER)
    fc_modules = get_fc_compiler_modules(MACHINE, COMPILER)
    ant_dir = get_ant_dir(MACHINE)
    top_install_dir = get_top_install_dir(MACHINE, RELEASE, COMPILER)
    install_dir = join_path(top_install_dir, '.installs', RELEASE)
    install_link = join_path(top_install_dir, RELEASE)
    std_install_dir = install_dir
    old_install_dir = None
    if link_exists(install_link):
        old_install_dir_path = os.readlink(install_link)
        if dir_exists(old_install_dir_path):
            old_install_dir = old_install_dir_path
            if install_dir == old_install_dir:
                install_dir += '.new'
        if dir_exists(install_dir):
            shutil.rmtree(install_dir)
    args = ['--install-dir=%s' % install_dir,
            '--release-tag=v%s' % RELEASE,
            '--c-compiler=%s' % cc,
            '--cxx-compiler=%s' % cxx,
            '--fc-compiler=%s' % fc]
    if fc_modules is not None and len(fc_modules) > 0:
        modules_str = ' '.join(fc_modules)
        args += ['--fc-compiler-module', modules_str]
    if ant_dir is not None:
        args += ['--ant-home-dir', ant_dir]
    if DISABLE_TESTS:
        args += ['--disable-tests']
    install(args)
    if link_exists(install_link):
        os.remove(install_link)
    os.symlink(install_dir, install_link, target_is_directory=True)
    if old_install_dir is not None:
        backup_dir = std_install_dir + '.old'
        if dir_exists(backup_dir):
            shutil.rmtree(backup_dir)
        shutil.move(old_install_dir, backup_dir)