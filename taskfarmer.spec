%define version 0.2
%define release 1

Summary: TaskFarmer Utility
Name: taskfarmer
Version: %{version}
Release: %{release}
Vendor: Lawrence Berkeley National Lab
License: GPL
Packager: Shane Canon <scanon@lbl.gov>
Group: System Environment/Base
Source0: %{name}-%{version}.tgz
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root/
Requires: perl

%description

%prep
%setup

%build
make

%install
if [ "$RPM_BUILD_ROOT" != "/" ]; then
	rm -rf $RPM_BUILD_ROOT
fi
%makeinstall


%clean
if [ "$RPM_BUILD_ROOT" != "/" ]; then
	rm -rf $RPM_BUILD_ROOT
fi

%files
%defattr(-,root,root)
/usr/bin/tfrun
/usr/libexec/taskfarmer
/usr/share/taskfarmer

%pre

%post
exit 0

%preun

%changelog
* Mon Sep 27 2010 Shane Canon <scanon@lbl.gov>
- Initial RPM

