Name:       blts-filesystem-perf

Summary:    BLTS filesystem performance test suite
Version:    0.0.1
Release:    0
Group:      Development/Testing
License:    GPLv2
URL:        https://github.com/mer-qa/blts-filesystem-perf
Source0:    %{name}-%{version}.tar.gz
Requires:   iozone
Requires:   bonnie++

%description
This package contains filesystem performance tests


%prep
%setup -q -n %{name}-%{version}

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/tests/blts-filesystem-perf
install --mode=755 run-bonnie++.sh %{buildroot}/opt/tests/blts-filesystem-perf
install --mode=755 run-iozone.sh %{buildroot}/opt/tests/blts-filesystem-perf
install --mode=644 tests.xml %{buildroot}/opt/tests/blts-filesystem-perf

%files
%defattr(-,root,root,-)
/opt/tests/blts-filesystem-perf/*
