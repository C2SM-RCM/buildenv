# Show the origin 
# echoes git@github.com:pspoerri/cosmo-pompa.git
function git_show_origin {
    path=$1
    if [ -z "${path}" ] ; then
    	path=$(pwd)
    fi
    echo $(git -C "${path}" config --get remote.origin.url)
 }

# Show the revision
# echoes cf28a6f
function git_show_revision {
    path=$1
    if [ -z "${path}" ] ; then
    	path=$(pwd)
    fi
    echo $(git -C "${path}" rev-parse --short HEAD)
}

# Show the check in date of the head
# echoes 2015-12-21 10:42:20 +0100
function git_show_checkindate {
    path=$1
    if [ -z "${path}" ] ; then
    	path=$(pwd)
    fi
    revision=$(git_show_revision "${path}")
    echo $(git -C "${path}" show -s --format=%ci ${revision})
}

# Show the current branch
# echoes buildenv
function git_show_branch {
	path=$1
    if [ -z "${path}" ] ; then
    	path=$(pwd)
    fi
    echo $(git -C "${path}" branch 2>/dev/null| sed -n '/^\*/s/^\* //p')
}

# Show all the branch information and where the head is pointing 
# echoes (HEAD -> buildenv, origin/buildenv)
function git_show_branch_all {
	path=$1
    if [ -z "${path}" ] ; then
    	path=$(pwd)
    fi
    echo $(git -C "${path}" log -n 1 --pretty=%d HEAD)
}

# Determines if the branch is dirty or not. 
function git_repository_is_clean {
    path=$1
    if [ -z "${path}" ] ; then
        path=$(pwd)
    fi
	git -C "${path}" diff --quiet 2>/dev/null >&2 
}

# Determines the status of a repository
# echoes clean or dirty
function git_show_repository_status {
    path=$1
    if [ -z "${path}" ] ; then
        path=$(pwd)
    fi
    if git_repository_is_clean "${path}" ; then
    	echo "clean"
    else
    	echo "dirty"
    fi
}

# Check if path is a git repository
# returns a unix 0, 1 return code depending on the status
function git_is_repository {
    path=$1
    if [ -z "${path}" ] ; then
        path=$(pwd)
    fi
    git -C "${path}" rev-parse --is-inside-work-tree 2>/dev/null >&2
}

# Show if path is a repository
# echoes true or false
function git_repository {
    path=$1
    if [ -z "${path}" ] ; then
        path=$(pwd)
    fi

    if git_is_repository "${path}" ; then
    	echo "true"
    else
    	echo "false"
    fi
}

# Pretty print git info
# echoes "No git repository" if we are not dealing with a git repository
# echoes "Rev cf28a6f (dirty) on buildenv from git@github.com:pspoerri/cosmo-pompa.git"
# otherwise
function git_info {
    path=$1
    
    if [ -z "${path}" ] ; then
        path=$(pwd)
    fi
    if ! git_is_repository "${path}" ; then
    	echo "No git repository"
    	exit 1
    fi

	revision=$(git_show_revision "${path}")
	branch=$(git_show_branch "${path}")
	origin=$(git_show_origin "${path}")
	dirty=""
	if ! git_repository_is_clean "${path}" ; then
		dirty=" ($(git_repository_status ${path}))"
	fi
	echo "Rev ${revision}${dirty} on ${branch} from ${origin}"
}

# Function to test the implementation
function test_functions {
    path=$1
    if [ -z "${path}" ] ; then
        path=$(pwd)
    fi

    echo Origin: $(git_show_origin "${path}")
    echo Revision: $(git_show_revision "${path}")
    echo Check in date: $(git_show_checkindate "${path}")
    echo Branch: $(git_show_branch "${path}")
    echo Branch all: $(git_show_branch_all "${path}")
    echo Status: $(git_show_repository_status "${path}")
    echo Repository?: $(git_is_repository "${path}")
    echo Info: $(git_info "${path}")
    echo Info no repo: $(git_info "/")
}

export -f git_show_origin
export -f git_show_revision
export -f git_show_checkindate
export -f git_show_branch
export -f git_show_branch_all
export -f git_repository_is_clean
export -f git_show_repository_status
export -f git_is_repository
export -f git_repository
export -f git_info
