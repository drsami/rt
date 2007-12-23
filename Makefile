# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
#
# DO NOT HAND-EDIT the file named 'Makefile'. This file is autogenerated.
# Have a look at "configure" and "Makefile.in" instead
#


PERL			= 	perl

CONFIG_FILE_PATH	=	/home/jesse/svk/3.999-DANGEROUS/etc
CONFIG_FILE		= 	$(CONFIG_FILE_PATH)/RT_Config.pm
SITE_CONFIG_FILE		= 	$(CONFIG_FILE_PATH)/RT_SiteConfig.pm


RT_VERSION_MAJOR	=	3
RT_VERSION_MINOR	=	7
RT_VERSION_PATCH	=	14

RT_VERSION =	$(RT_VERSION_MAJOR).$(RT_VERSION_MINOR).$(RT_VERSION_PATCH)
TAG 	   =	rt-$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERSION_PATCH)


# This is the group that all of the installed files will be chgrp'ed to.
RTGROUP			=	www


# User which should own rt binaries.
BIN_OWNER		=	root

# User that should own all of RT's libraries, generally root.
LIBS_OWNER 		=	root

# Group that should own all of RT's libraries, generally root.
LIBS_GROUP		=	bin

WEB_USER		=	www
WEB_GROUP		=	www


APACHECTL		=	/usr/sbin/apachectl

# {{{ Files and directories 

# DESTDIR allows you to specify that RT be installed somewhere other than
# where it will eventually reside

DESTDIR			=	


RT_PATH			=	/home/jesse/svk/3.999-DANGEROUS
RT_ETC_PATH		=	/home/jesse/svk/3.999-DANGEROUS/etc
RT_BIN_PATH		=	/home/jesse/svk/3.999-DANGEROUS/bin
RT_SBIN_PATH		=	/home/jesse/svk/3.999-DANGEROUS/sbin
RT_LIB_PATH		=	/home/jesse/svk/3.999-DANGEROUS/lib
RT_MAN_PATH		=	/home/jesse/svk/3.999-DANGEROUS/man
RT_VAR_PATH		=	/home/jesse/svk/3.999-DANGEROUS/var
RT_DOC_PATH		=	/home/jesse/svk/3.999-DANGEROUS/share/doc
RT_LOCAL_PATH		=	/home/jesse/svk/3.999-DANGEROUS/local
LOCAL_ETC_PATH		=	/home/jesse/svk/3.999-DANGEROUS/local/etc
LOCAL_LIB_PATH		=	/home/jesse/svk/3.999-DANGEROUS/local/lib
LOCAL_LEXICON_PATH	=	/home/jesse/svk/3.999-DANGEROUS/local/po
MASON_HTML_PATH		=	/home/jesse/svk/3.999-DANGEROUS/html
MASON_LOCAL_HTML_PATH	=	/home/jesse/svk/3.999-DANGEROUS/local/html
MASON_DATA_PATH		=	/home/jesse/svk/3.999-DANGEROUS/var/mason_data
MASON_SESSION_PATH	=	/home/jesse/svk/3.999-DANGEROUS/var/session_data
RT_LOG_PATH	    =       /home/jesse/svk/3.999-DANGEROUS/var/log

# RT_READABLE_DIR_MODE is the mode of directories that are generally meant
# to be accessable
RT_READABLE_DIR_MODE	=	0755




# {{{ all these define the places that RT's binaries should get installed

# RT_MODPERL_HANDLER is the mason handler script for mod_perl
RT_MODPERL_HANDLER	=	$(RT_BIN_PATH)/webmux.pl
# RT_STANDALONE_SERVER is a stand-alone HTTP server
RT_STANDALONE_SERVER	=	$(RT_BIN_PATH)/standalone_httpd
# RT_SPEEDYCGI_HANDLER is the mason handler script for SpeedyCGI
RT_SPEEDYCGI_HANDLER	=	$(RT_BIN_PATH)/mason_handler.scgi
# RT_FASTCGI_HANDLER is the mason handler script for FastCGI
RT_FASTCGI_HANDLER	=	$(RT_BIN_PATH)/mason_handler.fcgi
# RT_WIN32_FASTCGI_HANDLER is the mason handler script for FastCGI
RT_WIN32_FASTCGI_HANDLER	=	$(RT_BIN_PATH)/mason_handler.svc
# RT's CLI
RT_CLI_BIN		=	$(RT_BIN_PATH)/rt
# RT's mail gateway
RT_MAILGATE_BIN		=	$(RT_BIN_PATH)/rt-mailgate
# RT's cron tool
RT_CRON_BIN		=	$(RT_BIN_PATH)/rt-crontool

# }}}


BINARIES		=	$(DESTDIR)/$(RT_MODPERL_HANDLER) \
				$(DESTDIR)/$(RT_MAILGATE_BIN) \
				$(DESTDIR)/$(RT_CLI_BIN) \
				$(DESTDIR)/$(RT_CRON_BIN) \
				$(DESTDIR)/$(RT_STANDALONE_SERVER) \
				$(DESTDIR)/$(RT_SPEEDYCGI_HANDLER) \
				$(DESTDIR)/$(RT_FASTCGI_HANDLER) \
				$(DESTDIR)/$(RT_WIN32_FASTCGI_HANDLER)
SYSTEM_BINARIES		=	$(DESTDIR)/$(RT_SBIN_PATH)/

# }}}

# {{{ Web frontend

WEB_HANDLER		=	modperl1

# }}}

# {{{ Database setup

#
# DB_TYPE defines what sort of database RT trys to talk to
# "mysql" is known to work.
# "Pg" is known to work
# "Informix" is known to work

DB_TYPE			=	mysql

# Set DBA to the name of a unix account with the proper permissions and 
# environment to run your commandline SQL sbin

# Set DB_DBA to the name of a DB user with permission to create new databases 

# For mysql, you probably want 'root'
# For Pg, you probably want 'postgres' 
# For Oracle, you want 'system'
# For Informix, you want 'informix'

DB_DBA			=	root

DB_HOST			=	localhost

# If you're not running your database server on its default port, 
# specifiy the port the database server is running on below.
# It's generally safe to leave this blank 

DB_PORT			=	




#
# Set this to the canonical name of the interface RT will be talking to the 
# database on.  If you said that the RT_DB_HOST above was "localhost," this 
# should be too. This value will be used to grant rt access to the database.
# If you want to access the RT database from multiple hosts, you'll need
# to grant those database rights by hand.
#

DB_RT_HOST		=	localhost

# set this to the name you want to give to the RT database in 
# your database server. For Oracle, this should be the name of your sid

DB_DATABASE		=	rt3
DB_RT_USER		=	rt_user
DB_RT_PASS		=	rt_pass

# }}}


####################################################################

all: default

default:
	@echo "Please read RT's readme before installing. Not doing so could"
	@echo "be dangerous."



instruct:
	@echo "Congratulations. RT has been installed. "
	@echo ""
	@echo ""
	@echo "You must now configure RT by editing $(SITE_CONFIG_FILE)."
	@echo ""
	@echo "(You will definitely need to set RT's database password in "
	@echo "$(SITE_CONFIG_FILE) before continuing. Not doing so could be "
	@echo "very dangerous.  Note that you do not have to manually add a "
	@echo "database user or set up a database for RT.  These actions will be "
	@echo "taken care of in the next step.)"
	@echo ""
	@echo "After that, you need to initialize RT's database by running" 
	@echo " 'make initialize-database'"

#	@echo " or by executing "       
#	@echo " '$(RT_SBIN_PATH)/rt-setup-database --action init \ "
#	@echo "     --dba $(DB_DBA) --prompt-for-dba-password'"



upgrade-instruct: 
	@echo "Congratulations. RT has been upgraded. You should now check-over"
	@echo "$(CONFIG_FILE) for any necessary site customization. Additionally,"
	@echo "you should update RT's system database objects by running "
	@echo "   ls etc/upgrade"
	@echo ""
	@echo "For each item in that directory whose name is greater than"
	@echo "your previously installed RT version, run:"
	@echo "	   $(RT_SBIN_PATH)/rt-setup-database --dba $(DB_DBA) --prompt-for-dba-password --action schema --datadir etc/upgrade/<version>"
	@echo "	   $(RT_SBIN_PATH)/rt-setup-database --dba $(DB_DBA) --prompt-for-dba-password --action acl --datadir etc/upgrade/<version>"
	@echo "	   $(RT_SBIN_PATH)/rt-setup-database --dba $(DB_DBA) --prompt-for-dba-password --action insert --datadir etc/upgrade/<version>"


upgrade: config-install dirs files-install fixperms upgrade-instruct

upgrade-noclobber: config-install libs-install html-install bin-install local-install doc-install fixperms


# {{{ dependencies
testdeps:
	$(PERL) ./sbin/rt-test-dependencies --verbose --with-$(DB_TYPE) --with-$(WEB_HANDLER)

depends: fixdeps

fixdeps:
	$(PERL) ./sbin/rt-test-dependencies --verbose --install --with-$(DB_TYPE) --with-$(WEB_HANDLER)

#}}}

# {{{ fixperms
fixperms:
	# Make the libraries readable
	chmod $(RT_READABLE_DIR_MODE) $(DESTDIR)/$(RT_PATH)
	chown -R $(LIBS_OWNER) $(DESTDIR)/$(RT_LIB_PATH)
	chgrp -R $(LIBS_GROUP) $(DESTDIR)/$(RT_LIB_PATH)
	chmod -R  u+rwX,go-w,go+rX 	$(DESTDIR)/$(RT_LIB_PATH)


	chmod $(RT_READABLE_DIR_MODE) $(DESTDIR)/$(RT_BIN_PATH)
	chmod $(RT_READABLE_DIR_MODE) $(DESTDIR)/$(RT_BIN_PATH)	

	chmod 0755 $(DESTDIR)/$(RT_ETC_PATH)
	chmod 0500 $(DESTDIR)/$(RT_ETC_PATH)/*

	#TODO: the config file should probably be able to have its
	# owner set separately from the binaries.
	chown -R $(BIN_OWNER) $(DESTDIR)/$(RT_ETC_PATH)
	chgrp -R $(RTGROUP) $(DESTDIR)/$(RT_ETC_PATH)

	chmod 0550 $(DESTDIR)/$(CONFIG_FILE)
	chmod 0550 $(DESTDIR)/$(SITE_CONFIG_FILE)

	# Make the interfaces executable
	chown $(BIN_OWNER) $(BINARIES)
	chgrp $(RTGROUP) $(BINARIES)
	chmod 0755  $(BINARIES)

	# Make the web ui readable by all. 
	chmod -R  u+rwX,go-w,go+rX 	$(DESTDIR)/$(MASON_HTML_PATH) \
					$(DESTDIR)/$(MASON_LOCAL_HTML_PATH) \
					$(DESTDIR)/$(LOCAL_LEXICON_PATH)
	chown -R $(LIBS_OWNER) 	$(DESTDIR)/$(MASON_HTML_PATH) \
				$(DESTDIR)/$(MASON_LOCAL_HTML_PATH)
	chgrp -R $(LIBS_GROUP) 	$(DESTDIR)/$(MASON_HTML_PATH) \
				$(DESTDIR)/$(MASON_LOCAL_HTML_PATH)

	# Make the web ui's data dir writable
	chmod 0770  	$(DESTDIR)/$(MASON_DATA_PATH) \
			$(DESTDIR)/$(MASON_SESSION_PATH)
	chown -R $(WEB_USER) 	$(DESTDIR)/$(MASON_DATA_PATH) \
				$(DESTDIR)/$(MASON_SESSION_PATH)
	chgrp -R $(WEB_GROUP) 	$(DESTDIR)/$(MASON_DATA_PATH) \
				$(DESTDIR)/$(MASON_SESSION_PATH)
# }}}

# {{{ dirs
dirs:
	mkdir -p $(DESTDIR)/$(RT_LOG_PATH)
	mkdir -p $(DESTDIR)/$(MASON_DATA_PATH)
	mkdir -p $(DESTDIR)/$(MASON_DATA_PATH)/cache
	mkdir -p $(DESTDIR)/$(MASON_DATA_PATH)/etc
	mkdir -p $(DESTDIR)/$(MASON_DATA_PATH)/obj
	mkdir -p $(DESTDIR)/$(MASON_SESSION_PATH)
	mkdir -p $(DESTDIR)/$(MASON_HTML_PATH)
	mkdir -p $(DESTDIR)/$(MASON_LOCAL_HTML_PATH)
	mkdir -p $(DESTDIR)/$(LOCAL_ETC_PATH)
	mkdir -p $(DESTDIR)/$(LOCAL_LIB_PATH)
	mkdir -p $(DESTDIR)/$(LOCAL_LEXICON_PATH)
# }}}

install: config-install dirs files-install fixperms instruct

files-install: libs-install etc-install bin-install sbin-install html-install local-install doc-install

config-install:
	mkdir -p $(DESTDIR)/$(CONFIG_FILE_PATH)	
	-cp etc/RT_Config.pm $(DESTDIR)/$(CONFIG_FILE)
	[ -f $(DESTDIR)/$(SITE_CONFIG_FILE) ] || cp etc/RT_SiteConfig.pm $(DESTDIR)/$(SITE_CONFIG_FILE) 

	chgrp $(RTGROUP) $(DESTDIR)/$(CONFIG_FILE)
	chown $(BIN_OWNER) $(DESTDIR)/$(CONFIG_FILE)

	chgrp $(RTGROUP) $(DESTDIR)/$(SITE_CONFIG_FILE)
	chown $(BIN_OWNER) $(DESTDIR)/$(SITE_CONFIG_FILE)

	@echo "Installed configuration. about to install rt in  $(RT_PATH)"

TEST_FILES = t/*.t t/*/*.t
TEST_VERBOSE = 0

test: 
	prove -l $(TEST_FILES)

regression-install: config-install
	$(PERL) -pi -e 's/Set\(\$$Databasename.*\);/Set\(\$$Databasename, "rt3regression"\);/' $(DESTDIR)/$(CONFIG_FILE)

# {{{ database-installation

regression-reset-db: force-dropdb
	$(PERL) $(DESTDIR)/$(RT_SBIN_PATH)/rt-setup-database --action init --dba $(DB_DBA) --dba-password ''

initdb :: initialize-database

initialize-database: 
	$(PERL) $(DESTDIR)/$(RT_SBIN_PATH)/rt-setup-database --action init --dba $(DB_DBA) --prompt-for-dba-password

dropdb: 
	$(PERL)	$(DESTDIR)/$(RT_SBIN_PATH)/rt-setup-database --action drop --dba $(DB_DBA) --prompt-for-dba-password

force-dropdb: 
	$(PERL)	$(DESTDIR)/$(RT_SBIN_PATH)/rt-setup-database --action drop --dba $(DB_DBA) --dba-password '' --force

insert-approval-data: 
	$(PERL) $(DESTDIR)/$(RT_SBIN_PATH)/insert_approval_scrips
# }}}

# {{{ libs-install
libs-install: 
	[ -d $(DESTDIR)/$(RT_LIB_PATH) ] || mkdir -p $(DESTDIR)/$(RT_LIB_PATH)
	-cp -rp lib/* $(DESTDIR)/$(RT_LIB_PATH)
# }}}

# {{{ html-install
html-install:
	[ -d $(DESTDIR)/$(MASON_HTML_PATH) ] || mkdir -p $(DESTDIR)/$(MASON_HTML_PATH)
	-cp -rp ./html/* $(DESTDIR)/$(MASON_HTML_PATH)
# }}}

# {{{ doc-install
doc-install:
	# RT 3.0.0 - RT 3.0.2 would accidentally create a file instead of a dir
	-[ -f $(DESTDIR)/$(RT_DOC_PATH) ] && rm $(DESTDIR)/$(RT_DOC_PATH) 
	[ -d $(DESTDIR)/$(RT_DOC_PATH) ] || mkdir -p $(DESTDIR)/$(RT_DOC_PATH)
	-cp -rp ./README $(DESTDIR)/$(RT_DOC_PATH)
# }}}

# {{{ etc-install

etc-install:
	mkdir -p $(DESTDIR)/$(RT_ETC_PATH)
	-cp -rp \
		etc/acl.* \
		etc/initialdata \
		etc/schema.* \
		$(DESTDIR)/$(RT_ETC_PATH)
# }}}

# {{{ sbin-install

sbin-install:
	mkdir -p $(DESTDIR)/$(RT_SBIN_PATH)
	chmod +x \
		sbin/rt-dump-database \
		sbin/rt-setup-database \
		sbin/rt-test-dependencies \
		sbin/rt-clean-sessions \
		sbin/rt-shredder
	-cp -rp \
		sbin/rt-dump-database \
		sbin/rt-setup-database \
		sbin/rt-test-dependencies \
		sbin/rt-clean-sessions \
		sbin/rt-shredder \
		$(DESTDIR)/$(RT_SBIN_PATH)

# }}}

# {{{ bin-install

bin-install:
	mkdir -p $(DESTDIR)/$(RT_BIN_PATH)
	chmod +x bin/rt-mailgate \
		bin/rt-crontool
	-cp -rp \
		bin/rt-mailgate \
		bin/mason_handler.fcgi \
		bin/mason_handler.scgi \
		bin/standalone_httpd \
		bin/mason_handler.svc \
		bin/rt \
		bin/webmux.pl \
		bin/rt-crontool \
		$(DESTDIR)/$(RT_BIN_PATH)
# }}}

# {{{ local-install
local-install:
	-cp -rp ./local/html/* $(DESTDIR)/$(MASON_LOCAL_HTML_PATH)
	-cp -rp ./local/po/* $(DESTDIR)/$(LOCAL_LEXICON_PATH)
	-cp -rp ./local/etc/* $(DESTDIR)/$(LOCAL_ETC_PATH)
# }}}

# {{{ Best Practical Build targets -- no user servicable parts inside

regenerate-catalogs:
	$(PERL) sbin/extract-message-catalog

license-tag:
	$(PERL) sbin/license_tag

factory: initialize-database
	cd lib; $(PERL) ../sbin/factory  $(DB_DATABASE) RT

reconfigure:
	aclocal -I m4
	autoconf
	chmod 755 ./configure
	./configure

start-httpd:
	$(PERL) bin/standalone_httpd &

apachectl:
	$(APACHECTL) stop
	sleep 10
	$(APACHECTL) start
	sleep 5
# }}}
