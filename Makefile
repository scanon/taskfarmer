
prefix := /usr

NAME	= taskfarmer

BINFILES=	tfrun
LIBEXECFILES=	tf_worker tf_server tf_worker_thread
SHAREFILES=	share/carver.conf  share/franklin.conf  share/franklin.stage share/test.conf
EXAMPLEFILES=	examples/stage.sh examples/fix_perl_path.sh examples/sample.sh examples/pack.sh \
		examples/blast.qsub examples/stage.cloud.sh examples/sample.qsub examples/run.cloud

BINDIR=		$(prefix)/bin
LIBEXECDIR=	$(prefix)/libexec/$(NAME)
SHAREDIR=	$(prefix)/share/$(NAME)
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
