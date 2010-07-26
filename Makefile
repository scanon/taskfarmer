
PREFIX := /usr

NAME	= taskfarmer

BINFILES=	tfrun
LIBEXECFILES=	tf_worker tf_server
SHAREFILES=	share/carver.conf  share/franklin.conf  share/franklin.stage
EXAMPLEFILES=	examples/stage.sh examples/fix_perl_path.sh examples/sample.sh examples/pack.sh \
		examples/blast.qsub examples/stage.cloud.sh examples/sample.qsub examples/run.cloud

BINDIR=		$(PREFIX)/bin
LIBEXECDIR=	$(PREFIX)/libexec
SHAREDIR=	$(PREFIX)/share/$(NAME)
EXAMPLESDIR=	$(SHAREDIR)/examples

all:

install:
	install -d -D $(BINDIR)
	install -d -D $(LIBEXECDIR)
	install -d -D $(SHAREDIR)
	install -d -D $(EXAMPLESDIR)
	install -t $(BINDIR) $(BINFILES)
	install -t $(LIBEXECDIR) $(LIBEXECFILES)
	install -m 644 -t $(SHAREDIR) $(SHAREFILES)
	install -m 644 -t $(EXAMPLESDIR) $(EXAMPLEFILES)
